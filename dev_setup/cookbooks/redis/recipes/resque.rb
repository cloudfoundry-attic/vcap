directory "#{node[:redis_resque][:persistence_dir]}" do
  owner node[:deployment][:user]
  group node[:deployment][:user]
  mode "0755"
end

template File.join(node[:deployment][:config_path], "vcap_redis.conf") do
  source "vcap_redis.conf.erb"
  mode 0600
  owner node[:deployment][:user]
  group node[:deployment][:group]
end
