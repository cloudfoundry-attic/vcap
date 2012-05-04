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

bash "Install memcached" do
  cwd File.join("", "tmp")
  user node[:deployment][:inuser]
  code <<-EOH

  # TODO: check if lib event is installed
  # TODO: check and install saslauthd and configure /etc/sasldb if required

  tar xzf memcached-#{node[:memcached][:version]}.tar.gz
  cd memcached-#{node[:memcached][:version]}
  ./configure --enable-sasl
  make
  cp memcached #{File.join(node[:memcached][:path], "bin")}
  EOH
  not_if do
    ::File.exists?(File.join(node[:memcached][:path], "bin", "memcached"))
  end
end
