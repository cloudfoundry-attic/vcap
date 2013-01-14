include_attribute "deployment"
include_attribute "service"

include_attribute "backup"
include_attribute "service_lifecycle"

default[:redis][:supported_versions] = {
        "2.2" => "2.2.15",
        "2.4" => "2.4.17",
        "2.6" => "2.6.2"
}

default[:redis][:version_aliases] = {
        "current" => "2.6",
        "deprecated"    => "2.2"
}

default[:redis][:default_version] = "2.6"

default[:redis][:path] = File.join(node[:service][:path], "redis")
default[:redis][:runner] = node[:deployment][:user]
default[:redis][:port] = 6379
default[:redis][:password] = "redis"
default[:redis][:expire] = 60

default[:redis][:id] = {
  "2.2.15" => "eyJzaWciOiJ0akRiejV6Mk9aT2ZLcHlqdHJCaW1QbnJrVUk9Iiwib2lkIjoi%0ANGU0ZTc4YmNhNDFlMTIyMjA0ZTRlOTg2M2QwNzYzMDUwMTlmOGY5YzVkZjci%0AfQ==%0A",
  "2.4.17" => "eyJvaWQiOiI0ZTRlNzhiY2E2MWUxMjEyMDRlNGU4NmVlYmU1OTEwNTA3ZGFm%0AMjE5NTk4NCIsInNpZyI6InM2cFlCZGNRc3poaDdESXVOVzh3MkpFNkVuZz0i%0AfQ==%0A",
  "2.6.2"  => "eyJvaWQiOiI0ZTRlNzhiY2E0MWUxMjIyMDRlNGU5ODYzZDA3NjMwNTA5MDE0%0AZWRhOTNhMiIsInNpZyI6IlU3emJuaW1VV2dsR2RyTnU2Ym5HZllkNVhLRT0i%0AfQ==%0A"
}

default[:redis][:checksum] = {
  "2.2.15" => "4143b7fab809c5fe586265b4f792f346206a3a8082bbf79f70081a0538bab3cb",
  "2.4.17" => "3fae7c47ef84886ff65073593c91586bb675babaf702eb6f3b37855ab3066ebd",
  "2.6.2"  => "b3b2e74ec8a13337e5e17cc24b0fecf5d612d6a0835d99bd1e337b391f20a46d"
}

default[:redis_gateway][:service][:timeout] = "15"
default[:redis_gateway][:node_timeout] = "5"

default[:redis_node][:capacity] = "200"
default[:redis_node][:index] = "0"
default[:redis_node][:max_memory] = "16"
default[:redis_node][:token] = "changeredistoken"
default[:redis_node][:op_time_limit] = "6"
default[:redis_node][:redis_timeout] = "2"
default[:redis_node][:redis_start_timeout] = "3"

default[:redis_backup][:config_file] = "redis_backup.yml"
default[:redis_backup][:cron_time] = "0 3 * * *"
default[:redis_backup][:cron_file] = "redis_backup.cron"

default[:redis_resque][:config_file] = "services_redis.conf"
default[:redis_resque][:persistence_dir] = "/var/vcap/services_redis"

default[:redis_worker][:config_file] = "redis_worker.yml"
