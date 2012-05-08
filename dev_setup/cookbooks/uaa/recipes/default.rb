#
# Cookbook Name:: uaa
# Recipe:: default
#
# Copyright 2011, VMWARE
#
#

template "uaa.yml" do
  path File.join(node[:deployment][:config_path], "uaa.yml")
  source "uaa.yml.erb"
  owner node[:deployment][:user]
  mode 0644
end

bash "Build and Deploy UAA" do
  user node[:deployment][:user]
  code <<-EOH
    cd #{node[:cloudfoundry][:path]}/uaa; #{node[:maven][:path]}/bin/mvn clean package -U -DskipTests=true
    rm -Rf #{node[:tomcat][:base]}/webapps/ROOT
    cp -f #{node[:cloudfoundry][:path]}/uaa/uaa/target/cloudfoundry-identity-uaa-1.0.0.BUILD-SNAPSHOT.war #{node[:tomcat][:base]}/webapps/ROOT.war
  EOH
end
