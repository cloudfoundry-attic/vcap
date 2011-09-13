include_recipe "nginx::default"

# cloud controller nginx configuration file
template "cloud_controller_nginx.conf" do
  path File.join(node[:nginx][:prefix], "conf", "cloud_controller_nginx.conf")
  source "cloud_controller.conf.erb"
  owner "root"
  group "root"
  mode 0644
end

# cloud controller init script
template "cc_nginx" do
  path File.join("", "etc", "init.d", "cc_nginx")
  source "cc_nginx.erb"
  owner node[:deployment][:user]
  mode 0755
  notifies :restart, "service[cc_nginx]"
end

service "cc_nginx" do
  supports :status => true, :restart => true, :reload => true
  action [ :enable, :start ]
end
