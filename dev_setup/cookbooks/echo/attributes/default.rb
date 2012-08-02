include_attribute "deployment"

default[:echo][:host] = "localhost"

default[:echo_node][:capacity] = "100"
default[:echo_node][:index] = "0"
default[:echo_node][:token] = "changeechotoken"

default[:echo_server][:id] = "eyJzaWciOiJkUGRoT1F5UHBORWlnNStzUkl4Y1k5MC9mMUk9Iiwib2lkIjoi%0ANGU0ZTc4YmNhNjFlMTIxMjA0ZTRlODZlZWJlNTkxMDUwMThlZGM1ZjExNWYi%0AfQ==%0A"
default[:echo_server][:checksum] = "a1a3e89ae72ceb8f05106ad0666e4638077591090f28797ec240ded4956b610e"
default[:echo_server][:path] = File.join(node[:deployment][:home], "deploy", "echoserver")
default[:echo_server][:port] = 5002
