include_attribute "deployment"
default[:rabbitmq][:version] = "2.4.1"
default[:rabbitmq][:version_full] = "generic-unix-2.4.1"
default[:rabbitmq][:path] = File.join(node[:deployment][:home], "deploy", "rabbitmq")
default[:rabbitmq][:source] = "http://www.rabbitmq.com/releases/rabbitmq-server/v#{rabbitmq[:version]}/rabbitmq-server-#{rabbitmq[:version_full]}.tar.gz"
default[:rabbitmq][:plugins] = ["amqp_client", "mochiweb", "rabbitmq-management", "rabbitmq-management-agent", "rabbitmq-mochiweb", "webmachine"]
default[:rabbitmq][:plugins_source] = "http://www.rabbitmq.com/releases/plugins/v#{rabbitmq[:version]}/"

default[:rabbitmq][:checksums][:rabbitmq_server] = "47fa34be18d9a28c02503db04b7d66f85efa2722f8158451c06e7a6437630896"
default[:rabbitmq][:checksums][:plugins][:amqp_client] = "f3863d64c771343439213b935fdb0ec9e2e64f97d043def953a63432cf578f27"
default[:rabbitmq][:checksums][:plugins][:mochiweb] = "05efda15d0fe25234fdf10e416c54962fc95e384d136d2ff6aa9ee72f1872a12"
default[:rabbitmq][:checksums][:plugins][:rabbitmq_management] = "0ba21698eb4779093cc6099dbc5b5141b79fa93f2fbe31dbb5eb27818e574a75"
default[:rabbitmq][:checksums][:plugins][:rabbitmq_management_agent] = "073935b4f1f4ede7cac5693cca1b40bb11d2b9efaef417cf38ebfabecd4f5b33"
default[:rabbitmq][:checksums][:plugins][:rabbitmq_mochiweb] = "c5b49424fdd0f973d75fac5ffacf60901a608301a7f38fe7d82a8e68d84467e4"
default[:rabbitmq][:checksums][:plugins][:webmachine]= "bddd35f31ac33a1685c8aab60f84683e9f7324e9e5299f82f04d63682a6f9858"

default[:rabbitmq_node][:index] = "0"
default[:rabbitmq_node][:token] = "changerabbitmqtoken"
