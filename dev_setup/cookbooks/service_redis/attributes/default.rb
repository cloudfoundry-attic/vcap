include_attribute "deployment"

default[:service_redis][:path] = File.join(node[:deployment][:home], "deploy", "service_redis")

default[:service_redis][:id] = "eyJzaWciOiJ0akRiejV6Mk9aT2ZLcHlqdHJCaW1QbnJrVUk9Iiwib2lkIjoi%0ANGU0ZTc4YmNhNDFlMTIyMjA0ZTRlOTg2M2QwNzYzMDUwMTlmOGY5YzVkZjci%0AfQ==%0A"
default[:service_redis][:checksum] = "4143b7fab809c5fe586265b4f792f346206a3a8082bbf79f70081a0538bab3cb"

default[:service_redis][:persistence_dir] = "/var/vcap/services_redis"

default[:service_redis][:host] = "localhost"
default[:service_redis][:port] = 4999
default[:service_redis][:password] = "redis"
default[:service_redis][:expire] = 60
