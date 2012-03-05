default[:rabbitmq][:version] = "2.4.0"
default[:rabbitmq][:version_full] = "2.4.0-1_all"
default[:rabbitmq][:source] = "http://www.rabbitmq.com/releases/rabbitmq-server/v#{rabbitmq[:version]}/rabbitmq-server_#{rabbitmq[:version_full]}.deb"

default[:rabbit_node][:token] = "changerabbitmqtoken"
default[:rabbit_node][:index] = "0"
default[:rabbit_node][:available_memory] = "1024"
default[:rabbit_node][:max_memory] = "16"

default[:rabbitmq_node][:token] = node[:rabbit_node][:token]