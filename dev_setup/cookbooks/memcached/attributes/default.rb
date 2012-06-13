include_attribute "deployment"
default[:libevent][:version] = "2.0.19"
default[:libevent][:id] = "eyJzaWciOiJIaWtwTHBwS3QyMjZQUDdycHJuTlFYQWlFRDA9Iiwib2lkIjoi%0ANGU0ZTc4YmNhMTFlMTIyMDA0ZTRlOGVjNjQ4NDMxMDRmYjZkNjI0M2ViZmMi%0AfQ==%0A"
default[:memcached][:version] = "1.4.13"
default[:memcached][:path] = File.join(node[:deployment][:home], "deploy", "memcached")
default[:memcached][:id] = "eyJzaWciOiIyRy9MK0JsbEtTYnF2SjgwLzZ2Qm5qbE93VDA9Iiwib2lkIjoi%0ANGU0ZTc4YmNhMTFlMTIyMjA0ZTRlOTg2MzhiNzYzMDRmYjZkNjI4ZDI4Y2Ii%0AfQ==%0A"
default[:memcached][:runner] = node[:deployment][:user]
default[:memcached][:password] = "memcached"

default[:memcached][:checksums][:libevent] = "1591fb411a67876a514a33df54b85417b31e01800284bcc6894fc410c3eaea21"
default[:memcached][:checksums][:memcached] = "cb0b8b87aa57890d2327906a11f2f1b61b8d870c0885b54c61ca46f954f27e29"

default[:memcached_node][:index] = "0"
default[:memcached_node][:capacity] = "5"
default[:memcached_node][:token] = "changememcachedtoken"
