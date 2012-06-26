include_attribute "deployment"

include_attribute "backup"
include_attribute "service_lifecycle"

default[:redis][:version] = "2.2.15"
default[:redis][:path] = File.join(node[:deployment][:home], "deploy", "redis")
default[:redis][:runner] = node[:deployment][:user]
default[:redis][:port] = 6379
default[:redis][:password] = "redis"
default[:redis][:expire] = 60

default[:redis][:id] = "eyJvaWQiOiI0ZTRlNzhiY2ExMWUxMjIyMDRlNGU5ODYzOGI3NjMwNGZlOTJj%0AMzc1Yjc3MCIsInNpZyI6IlBPUkw5WDkxYmErTnlXdnNyWlVaOEtrV1JQZz0i%0AfQ==%0A"
default[:redis][:checksum] = "4143b7fab809c5fe586265b4f792f346206a3a8082bbf79f70081a0538bab3cb"

default[:redis_node][:capacity] = "200"
default[:redis_node][:index] = "0"
default[:redis_node][:max_memory] = "16"
default[:redis_node][:token] = "changeredistoken"

default[:redis_backup][:config_file] = "redis_backup.yml"
default[:redis_backup][:cron_time] = "0 3 * * *"
default[:redis_backup][:cron_file] = "redis_backup.cron"

default[:redis_resque][:config_file] = "vcap_redis.conf"
default[:redis_resque][:persistence_dir] = "/var/vcap/vcap_redis"

default[:redis_worker][:config_file] = "redis_worker.yml"
