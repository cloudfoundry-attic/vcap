include_attribute "deployment"
default[:libevent][:version] = "2.0.19"
default[:memcached][:version] = "1.4.13"
default[:memcached][:path] = File.join(node[:deployment][:home], "deploy", "memcached")
default[:memcached][:runner] = node[:deployment][:user]
default[:memcached][:password] = "memcached"

default[:memcached_node][:index] = "0"
default[:memcached_node][:capacity] = "5"
default[:memcached_node][:token] = "changememcachedtoken"
