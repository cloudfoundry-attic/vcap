include_attribute "deployment"

default[:echo][:supported_versions] = {
        "1.0" => "1.0",
}
default[:echo][:version_aliases] = {
        "current" => "1.0",
}
default[:echo][:default_version] = "1.0"

default[:echo][:host] = "localhost"

default[:echo_gateway][:service][:timeout] = "15"

default[:echo_node][:capacity] = "100"
default[:echo_node][:index] = "0"
default[:echo_node][:token] = "changeechotoken"

default[:echo_server][:id] = "eyJzaWciOiJEV2p4dThyeVlGd3M0TGgybkVwNHFtQTFqTlU9Iiwib2lkIjoi%0ANGU0ZTc4YmNhNjFlMTIxMjA0ZTRlODZlZWJlNTkxMDUwMjMzMjVmNGRkMTIi%0AfQ==%0A"
default[:echo_server][:checksum] = "a4d5976dfff5d0c9e14fd6eaaa587fcc2543f18c88e3f28960cd18d04c1fa7c9"
default[:echo_server][:path] = File.join(node[:deployment][:home], "deploy", "echoserver")
default[:echo_server][:port] = 5002
