include_attribute "deployment"

default[:vcap_redis][:path] = File.join(node[:deployment][:home], "deploy", "vcap_redis")

default[:vcap_redis][:id] = "eyJzaWciOiJ0akRiejV6Mk9aT2ZLcHlqdHJCaW1QbnJrVUk9Iiwib2lkIjoi%0ANGU0ZTc4YmNhNDFlMTIyMjA0ZTRlOTg2M2QwNzYzMDUwMTlmOGY5YzVkZjci%0AfQ==%0A"
default[:vcap_redis][:checksum] = "4143b7fab809c5fe586265b4f792f346206a3a8082bbf79f70081a0538bab3cb"

default[:vcap_redis][:port] = "5454"
default[:vcap_redis][:password] = "PoIxbL98RWpwBuUJvKNojnpIcRb1ot2"
