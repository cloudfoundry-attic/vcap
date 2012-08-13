include_attribute "deployment"

default[:memcached][:supported_versions] = {
        "1.4" => "1.4.13",
}
default[:memcached][:version_aliases] = {
        "current" => "1.4",
}
default[:memcached][:default_version] = "1.4"

default[:libevent][:version] = "2.0.19"
default[:libevent][:id] = "eyJzaWciOiJoemRHWEtZTWdKYm9OSUJIeU5kcHc5Ti9TNEk9Iiwib2lkIjoi%0ANGU0ZTc4YmNhNTFlMTIyMjA0ZTRlOTg2M2YyOGYzMDUwMTlmOWMxYzE4N2Ei%0AfQ==%0A"
default[:memcached][:path] = File.join(node[:deployment][:home], "deploy", "memcached")
default[:memcached][:id] = "eyJzaWciOiJmZzdRNDJvZ3pZTnYvNHBjeEpjM1UvMWVVK2c9Iiwib2lkIjoi%0ANGU0ZTc4YmNhNTFlMTIxMjA0ZTRlODZlZThlMmM5MDUwMTlmOWJhY2UxYWIi%0AfQ==%0A"
default[:memcached][:runner] = node[:deployment][:user]
default[:memcached][:password] = "memcached"

default[:memcached][:checksums][:libevent] = "1591fb411a67876a514a33df54b85417b31e01800284bcc6894fc410c3eaea21"
default[:memcached][:checksums][:memcached] = "cb0b8b87aa57890d2327906a11f2f1b61b8d870c0885b54c61ca46f954f27e29"

default[:memcached_gateway][:service][:timeout] = "15"
default[:memcached_gateway][:node_timeout] = "5"

default[:memcached_node][:index] = "0"
default[:memcached_node][:capacity] = "5"
default[:memcached_node][:token] = "changememcachedtoken"
default[:memcached_node][:op_time_limit] = "6"
