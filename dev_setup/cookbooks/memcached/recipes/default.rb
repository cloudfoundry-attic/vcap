libevent_tarball_path = File.join(node[:deployment][:setup_cache], "libevent-#{node[:libevent][:version]}-stable.tar.gz")
cf_remote_file libevent_tarball_path do
  owner node[:deployment][:user]
  source node[:libevent][:source]
  checksum node[:memcached][:checksums][:libevent]
end

memcached_tarball_path = File.join(node[:deployment][:setup_cache], "memcached-#{node[:memcached][:version]}.tar.gz")
cf_remote_file memcached_tarball_path do
  owner node[:deployment][:user]
  source node[:memcached][:source]
  checksum node[:memcached][:checksums][:memcached]
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
  tar xzf #{libevent_tarball_path}
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
  tar xzf #{memcached_tarball_path}
  cd memcached-#{node[:memcached][:version]}
  ./configure --with-libevent=../libevent-#{node[:libevent][:version]}-stable/tmp LDFLAGS="-static"
  make
  cp memcached #{File.join(node[:memcached][:path], "bin")}
  EOH
  not_if do
    ::File.exists?(File.join(node[:memcached][:path], "bin", "memcached"))
  end
end
