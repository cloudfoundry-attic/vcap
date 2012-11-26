include_attribute "deployment"

default[:rabbitmq][:supported_versions] = {
        "2.4" => "2.4.1",
        "2.8" => "2.8.7",
}
default[:rabbitmq][:version_aliases] = {
        "deprecated" => "2.8",
        "current"    => "2.4",
}
default[:rabbitmq][:default_version] = "2.4"

default[:rabbitmq][:path] = File.join(node[:deployment][:home], "deploy", "rabbitmq")
default[:rabbitmq][:id] = {
  "2.4.1" => "eyJzaWciOiJOTWRVQm01RHU3c1RXcHF4dUovUm93S1c0UUU9Iiwib2lkIjoi%0ANGU0ZTc4YmNhNDFlMTIxMjA0ZTRlODZlZTUzOTIxMDUwMTlmYTU0YWRkZTEi%0AfQ==%0A",
  "2.8.7" => "eyJvaWQiOiI0ZTRlNzhiY2E0MWUxMjEwMDRlNGU3ZDUxNzYxOGYwNTBiMzI2%0ANzM2ODZlZCIsInNpZyI6IjkwaDNnYnRuUzJKTXhSZmpVSlZxanUwT1RRYz0i%0AfQ==%0A",
}

default[:rabbitmq][:checksum] = {
  "2.4.1" => "0a87dfe4489b0ddabfee7306536530934a4d4518ef0821e08634c7a07d4cf732",
  "2.8.7" => "7a177c541ad6a33d639330d09503d0948e77208323bd8e603c48e40cd041a432",
}

default[:rabbitmq_gateway][:service][:timeout] = "15"
default[:rabbitmq_gateway][:node_timeout] = "10"

default[:rabbitmq_node][:index] = "0"
default[:rabbitmq_node][:token] = "changerabbitmqtoken"
default[:rabbitmq_node][:op_time_limit] = "6"
default[:rabbitmq_node][:rabbitmq_start_timeout] = "5"
