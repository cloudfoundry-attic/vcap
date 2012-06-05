include_attribute "deployment"
default[:rabbitmq][:version] = "2.4.1"
default[:rabbitmq][:version_full] = "generic-unix-2.4.1"
default[:rabbitmq][:path] = File.join(node[:deployment][:home], "deploy", "rabbitmq")
default[:rabbitmq][:id] = "eyJvaWQiOiI0ZTRlNzhiY2ExMWUxMjEwMDRlNGU3ZDUxMWY4MjEwNGY0NGYx%0AYmRjYmY0NSIsInNpZyI6IkZXWUQwYi9oQmtRdW9adjNJb0d6K1lzd0NuND0i%0AfQ==%0A"
default[:rabbitmq][:checksum] = "0a87dfe4489b0ddabfee7306536530934a4d4518ef0821e08634c7a07d4cf732"

default[:rabbitmq_gateway][:service][:timeout] = "15"
default[:rabbitmq_gateway][:node_timeout] = "10"

default[:rabbitmq_node][:index] = "0"
default[:rabbitmq_node][:token] = "changerabbitmqtoken"
default[:rabbitmq_node][:op_time_limit] = "6"
default[:rabbitmq_node][:rabbitmq_start_timeout] = "5"
