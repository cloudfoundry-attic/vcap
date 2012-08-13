include_attribute "deployment"

default[:rabbitmq][:supported_versions] = {
        "2.4" => "2.4.1",
}
default[:rabbitmq][:version_aliases] = {
        "current" => "2.4",
}
default[:rabbitmq][:default_version] = "2.4"

default[:rabbitmq][:version] = "2.4.1"
default[:rabbitmq][:version_full] = "generic-unix-2.4.1"
default[:rabbitmq][:path] = File.join(node[:deployment][:home], "deploy", "rabbitmq")
default[:rabbitmq][:id] = "eyJzaWciOiJOTWRVQm01RHU3c1RXcHF4dUovUm93S1c0UUU9Iiwib2lkIjoi%0ANGU0ZTc4YmNhNDFlMTIxMjA0ZTRlODZlZTUzOTIxMDUwMTlmYTU0YWRkZTEi%0AfQ==%0A"
default[:rabbitmq][:checksum] = "0a87dfe4489b0ddabfee7306536530934a4d4518ef0821e08634c7a07d4cf732"

default[:rabbitmq_gateway][:service][:timeout] = "15"
default[:rabbitmq_gateway][:node_timeout] = "10"

default[:rabbitmq_node][:index] = "0"
default[:rabbitmq_node][:token] = "changerabbitmqtoken"
default[:rabbitmq_node][:op_time_limit] = "6"
default[:rabbitmq_node][:rabbitmq_start_timeout] = "5"
