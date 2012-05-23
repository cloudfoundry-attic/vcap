include_attribute "deployment"
default[:libevent][:version] = "2.0.19"
default[:libevent][:source] = "http://cloud.github.com/downloads/libevent/libevent/libevent-#{node[:libevent][:version]}-stable.tar.gz"
default[:memcached][:version] = "1.4.13"
default[:memcached][:path] = File.join(node[:deployment][:home], "deploy", "memcached")
default[:memcached][:source] = "http://memcached.googlecode.com/files/memcached-#{node[:memcached][:version]}.tar.gz"
default[:memcached][:runner] = node[:deployment][:user]
default[:memcached][:password] = "memcached"

default[:memcached][:checksums][:libevent] = "1591fb411a67876a514a33df54b85417b31e01800284bcc6894fc410c3eaea21"
default[:memcached][:checksums][:memcached] = "cb0b8b87aa57890d2327906a11f2f1b61b8d870c0885b54c61ca46f954f27e29"

default[:memcached_node][:index] = "0"
default[:memcached_node][:capacity] = "5"
default[:memcached_node][:token] = "changememcachedtoken"
