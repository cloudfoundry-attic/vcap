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

bash "copy node to warden base" do
  code <<-EOH
  cp -r #{node[:node06][:path]}/* #{node[:warden][:rootfs_path]}/usr/
  EOH
end

template "vblob_startup.sh" do
   path File.join(node[:warden][:rootfs_path], "usr", "bin", "vblob_startup.sh")
   source "vblob_startup.sh.erb"
   mode 0755
end

template "services.conf" do
   path File.join(node[:warden][:rootfs_path], "etc", "init", "services.conf")
   source "services.conf.erb"
   mode 0644
end

node[:vblob][:supported_versions].each do |version|
  bash "install vblob version #{version}" do
    code <<-EOH
    mkdir -p #{File.join(node[:vblob][:path], version)}
    cd /tmp
    git reset --hard #{node[:vblob][:commit][version]}
    cp -af vblob/* #{File.join(node[:vblob][:path], version)}
    EOH
    not_if do
      ::File.exists?(File.join(node[:vblob][:path], version, "server.js"))
    end
  end
end
