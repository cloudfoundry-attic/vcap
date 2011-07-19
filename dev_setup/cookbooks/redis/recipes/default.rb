remote_file "/tmp/redis-#{node[:redis][:version]}.tar.gz" do
  owner node[:redis][:runner]
  source "http://redis.googlecode.com/files/redis-#{node[:redis][:version]}.tar.gz"
  not_if { ::File.exists?("/tmp/redis-#{node[:redis][:version]}.tar.gz") }
end

directory "#{node[:redis][:path]}" do
  owner node[:redis][:runner]
  group node[:redis][:runner]
  mode "0755"
end

%w[bin etc var].each do |dir|
  directory "#{node[:redis][:path]}/#{dir}" do
    owner node[:redis][:runner]
    group node[:redis][:runner]
    mode "0755"
    recursive true
    action :create
  end
end

bash "Install Redis" do
  cwd "/tmp"
  user node[:redis][:runner]
  code <<-EOH
  tar xzf redis-#{node[:redis][:version]}.tar.gz
  cd redis-#{node[:redis][:version]}
  make
  cd src
  cp redis-benchmark redis-cli redis-server redis-check-dump redis-check-aof #{node[:redis][:path]}/bin
  EOH
  not_if do
    ::File.exists?("#{node[:redis][:path]}/bin/redis-server")
  end
end

template "#{node[:redis][:path]}/etc/redis.conf" do
  source "redis.conf.erb"
  mode 0600
  owner node[:redis][:runner]
  group node[:redis][:runner]
end
