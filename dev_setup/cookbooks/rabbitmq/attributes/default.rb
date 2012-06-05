include_attribute "deployment"
default[:rabbitmq][:version] = "2.4.1"
default[:rabbitmq][:version_full] = "generic-unix-2.4.1"
default[:rabbitmq][:path] = File.join(node[:deployment][:home], "deploy", "rabbitmq")
default[:rabbitmq][:source] = "http://www.rabbitmq.com/releases/rabbitmq-server/v#{rabbitmq[:version]}/rabbitmq-server-#{rabbitmq[:version_full]}.tar.gz"
default[:rabbitmq][:plugins] = ["amqp_client", "mochiweb", "rabbitmq-management", "rabbitmq-management-agent", "rabbitmq-mochiweb", "webmachine"]
default[:rabbitmq][:plugins_source] = "http://www.rabbitmq.com/releases/plugins/v#{rabbitmq[:version]}/"

default[:rabbitmq_gateway][:service][:timeout] = "15"
default[:rabbitmq_gateway][:node_timeout] = "10"

default[:rabbitmq_node][:index] = "0"
default[:rabbitmq_node][:token] = "changerabbitmqtoken"
default[:rabbitmq_node][:rabbitmq_start_timeout] = "5"
