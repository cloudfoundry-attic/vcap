#
# Cookbook Name:: vblob
# Recipe:: default
#
# Copyright 2011, VMware
#
#

FileUtils.rm_rf(File.join("", "tmp", "vblob"))

bash "prepare to install vBlob" do
  cwd File.join(node[:node06][:path], "bin")
  user node[:deployment][:user]
  code <<-EOH
  ./node npm -g install express
  ./node npm -g install winston
  ./node npm -g install sax
  ./node npm -g install vows
  cd /tmp
  git clone #{node[:vblob][:source]}
  EOH
end

directory node[:vblob][:path] do
  owner node[:deployment][:user]
  group node[:deployment][:group]
  mode "0755"
  recursive true
  action :create
end

bash "install node js for vblob" do
  user node[:deployment][:user]
  code <<-EOH
    mkdir -p #{node[:vblob][:path]}/node
    cp -r #{node[:node06][:path]}/* #{node[:vblob][:path]}/node/
  EOH
  not_if do
    ::File.exists?(File.join(node[:vblob][:path], "node", "bin", "node"))
  end
end

bash "install vblob tools" do
  user node[:deployment][:user]
  code <<-EOH
    mkdir -p #{node[:vblob][:path]}/common/bin
    cp #{node[:service][:common_path]}/utils.sh #{node[:vblob][:path]}/common/bin
  EOH
end

template File.join(node[:vblob][:path], "common", "bin", "warden_service_ctl") do
   source "warden_service_ctl.erb"
   mode 0755
end

node[:vblob][:supported_versions].each do |version|
  bash "install vblob version #{version}" do
    user node[:deployment][:user]
    code <<-EOH
      mkdir -p #{File.join(node[:vblob][:path], version)}
      cd /tmp/vblob
      git reset --hard #{node[:vblob][:commit][version]}
      cp -af * #{File.join(node[:vblob][:path], version)}
    EOH
    not_if do
      ::File.exists?(File.join(node[:vblob][:path], version, "server.js"))
    end
  end
end
