
include_recipe "java"

case node.platform
when "redhat", "centos", "fedora"
  include_recipe "jpackage"
end

remote_file  File.join("", "tmp", "apache-tomcat-#{node[:tomcat][:version]}.tar.gz") do
  owner node[:deployment][:user]
  source node[:tomcat][:source]
  not_if { ::File.exists?(File.join("", "tmp", "apache-tomcat-#{node[:tomcat][:version]}.tar.gz")) }
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
  tarball = File.join("", "tmp", "apache-tomcat-#{node[:tomcat][:version]}.tar.gz")
  code <<-EOH
    tar xzf #{tarball}
    cp -Rf #{node[:tomcat][:base]}/apache-tomcat-#{node[:tomcat][:version]}/* #{node[:tomcat][:base]}
    rm -Rf #{node[:tomcat][:base]}/apache-tomcat-#{node[:tomcat][:version]}
  EOH
  not_if do
    ::File.exists?(File.join(node[:tomcat][:base], "bin", "catalina.sh"))
  end
end
