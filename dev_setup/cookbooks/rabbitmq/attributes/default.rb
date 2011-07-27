default[:rabbitmq][:version] = "2.4.0"
default[:rabbitmq][:version_full] = "2.4.0-1_all"
default[:rabbitmq][:source] = "http://www.rabbitmq.com/releases/rabbitmq-server/v#{rabbitmq[:version]}/rabbitmq-server_#{rabbitmq[:version_full]}.deb"
