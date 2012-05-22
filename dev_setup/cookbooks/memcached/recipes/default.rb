remote_file File.join("", "tmp", "libevent-#{node[:libevent][:version]}-stable.tar.gz") do
  owner node[:deployment][:user]
  source "https://github.com/downloads/libevent/libevent/libevent-#{node[:libevent][:version]}-stable.tar.gz"
  not_if { ::File.exists?(File.join("", "tmp", "libevent-#{node[:libevent][:version]}-stable.tar.gz")) }
end

remote_file File.join("", "tmp", "memcached-#{node[:memcached][:version]}.tar.gz") do
  owner node[:deployment][:user]
  source "http://memcached.googlecode.com/files/memcached-#{node[:memcached][:version]}.tar.gz"
  not_if { ::File.exists?(File.join("", "tmp", "memcached-#{node[:memcached][:version]}.tar.gz")) }
end

directory "#{node[:memcached][:path]}" do
  owner node[:deployment][:user]
  group node[:deployment][:user]
  mode "0755"
end

%w[bin etc var].each do |dir|
  directory File.join(node[:memcached][:path], dir) do
    owner node[:deployment][:user]
    group node[:deployment][:user]
    mode "0755"
    recursive true
    action :create
  end
end

bash "Compile libevent" do
  cwd File.join("", "tmp")
  user node[:deployment][:user]
  code <<-EOH
  tar xzf libevent-#{node[:libevent][:version]}-stable.tar.gz
  cd libevent-#{node[:libevent][:version]}-stable
  ./configure --prefix=`pwd`/tmp
  make
  make install
  EOH
  not_if do
    ::File.exists?(File.join(node[:memcached][:path], "bin", "memcached"))
  end
end

bash "Install memcached" do
  cwd File.join("", "tmp")
  user node[:deployment][:user]
  code <<-EOH
  tar xzf memcached-#{node[:memcached][:version]}.tar.gz
  cd memcached-#{node[:memcached][:version]}
  ./configure --with-libevent=../libevent-#{node[:libevent][:version]}-stable/tmp LDFLAGS="-static"
  make
  cp memcached #{File.join(node[:memcached][:path], "bin")}
  EOH
  not_if do
    ::File.exists?(File.join(node[:memcached][:path], "bin", "memcached"))
  end
end
