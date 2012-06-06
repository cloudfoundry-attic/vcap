#
# Cookbook Name:: backup
# Recipe:: default
#
# Copyright 2011, VMware
#

node[:backup][:mountpoint_check_tolerent] = "-t"
# generate the service_backup_ctl
template "service_backup_ctl" do
  source "service_backup_ctl.erb"
  path File.join(node[:cloudfoundry][:home], "vcap", "dev_setup", "bin", "service_backup_ctl")
  mode "0755"
  owner node[:deployment][:user]
  group node[:deployment][:group]
end

# umount it first
bash "umount_it" do
  user "root"
  code <<-EOH
    mount -l | grep "#{node[:backup][:mount_point]}" > /dev/null
    if test $? -eq 0
    then
      umount -d #{node[:backup][:mount_point]}
    fi
  EOH
end

# create mount point
directory node[:backup][:mount_point] do
  owner node[:deployment][:user]
  group node[:deployment][:group]
  mode "0755"
  recursive true
end

if node[:backup][:backend] == "nfs"
  # use nfs
  case node[:nfs_server][:host]
  when "127.0.0.1", "localhost", cf_local_ip
    bash "mount_local_exported_dir" do
      user "root"
      code <<-EOH
        # if nfs server running in the same node, just use bindmount
        mount --bind #{node[:nfs_server][:exports_dir]} #{node[:backup][:mount_point]}
      EOH
    end
  else
    node[:backup][:mountpoint_check_tolerent] = ""
    # install nfs client
    include_recipe "nfs::client"
    # mount remote nfs direcotry
    mount node[:backup][:mount_point] do
      mount_point node[:backup][:mount_point]
      device "#{node[:nfs_server][:host]}:#{node[:nfs_server][:exports_dir]}"
      fstype "nfs"
      options "rw"
    end
  end
end
