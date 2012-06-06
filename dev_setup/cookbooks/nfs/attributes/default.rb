incldue_attribute "deployment"
default[:nfs][:server_no_root_squash] = false
default[:nfs][:server_exports_dir] = "/var/vcap/nfs"
default[:nfs][:server_exports_template] = "exports.conf"
default[:nfs][:server_local_ip] = "127.0.0.1"
default[:nfs][:server_local_subnet] = "127.0.0.1"
default[:nfs][:idmapd_template] = "idmapd.conf"
default[:nfs][:idmapd_domain] = "localdomain"
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
