
include_recipe "java"

case node.platform
when "redhat", "centos", "fedora"
  include_recipe "jpackage"
end

tomcat_tarball_path = File.join(node[:deployment][:setup_cache], "apache-tomcat-#{node[:tomcat][:version]}.tar.gz")
cf_remote_file tomcat_tarball_path do
  owner node[:deployment][:user]
  id node[:tomcat][:id]
  checksum node[:tomcat][:checksum]
end

directory node[:tomcat][:base] do
  owner node[:deployment][:user]
  group node[:deployment][:group]
  mode "0755"
  recursive true
  action :create
end

bash "Install Tomcat #{node[:tomcat][:path]}" do
  cwd "#{node[:tomcat][:base]}"
  user node[:deployment][:user]
  code <<-EOH
    tar xzf #{tomcat_tarball_path}
    cp -Rf #{node[:tomcat][:base]}/apache-tomcat-#{node[:tomcat][:version]}/* #{node[:tomcat][:base]}
    rm -Rf #{node[:tomcat][:base]}/apache-tomcat-#{node[:tomcat][:version]}
  EOH
end
