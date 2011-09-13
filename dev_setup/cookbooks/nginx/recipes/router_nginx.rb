include_recipe "nginx::default"

template "cloud_controller_nginx.conf" do
  path File.join(node[:nginx][:prefix], "conf", "cloud_controller_nginx.conf")
  source "cloud_controller.conf.erb"
  owner "root"
  group "root"
  mode 0644
end

template "router_nginx" do
  path File.join("", "etc", "init.d", "router_nginx")
  source "router_nginx.erb"
  owner node[:deployment][:user]
  mode 0755
  notifies :restart, "service[router_nginx]"
end

service "router_nginx" do
  supports :status => true, :restart => true, :reload => true
  action [ :enable, :start ]
end
