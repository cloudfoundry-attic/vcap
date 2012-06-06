incldue_attribute "deployment"
default[:nfs_server][:no_root_squash] = false
default[:nfs_server][:exports_dir] = "/var/vcap/nfs"
default[:nfs_server][:host] = "127.0.0.1"
default[:nfs_server][:idmapd_domain] = "localdomain"
default[:nfs][:service_server] = "nfs-kernel-server"
default[:nfs][:service_portmap] = "portmap"
default[:nfs][:service_lock] = "statd"
case node["platform"]
when "ubuntu"
    default[:nfs][:packages] = %w[nfs-common portmap]
  if node["platform_version"].to_i >= 11
    default[:nfs][:packages] = %w[nfs-common rpcbind]
    default[:nfs][:service_portmap] = "rpcbind"
  end
  if node["platform_version"].to_i >=12
    default[:nfs][:service_portmap] = "rpcbind-boot"
  end
end
