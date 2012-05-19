#
# Cookbook Name:: uaa
# Recipe:: default
#
# Copyright 2011, VMWARE
#
#


cf_pg_reset_user_password(:uaadb)
cf_pg_reset_user_password(:ccdb)

template "uaa.yml" do
  path File.join(node[:deployment][:config_path], "uaa.yml")
  source "uaa.yml.erb"
  owner node[:deployment][:user]
  mode 0644
end

bash "Build and Deploy UAA" do
  user node[:deployment][:user]
  code <<-EOH
    cd #{node[:cloudfoundry][:path]}/uaa; #{node[:maven][:path]}/bin/mvn clean install -U -DskipTests=true
    rm -Rf #{node[:tomcat][:base]}/webapps/ROOT
    cp -f #{node[:cloudfoundry][:path]}/uaa/uaa/target/cloudfoundry-identity-uaa-*.war #{node[:tomcat][:base]}/webapps/ROOT.war
  EOH
end

cf_bundle_install(File.expand_path(File.join(node["cloudfoundry"]["path"], "uaa")))
