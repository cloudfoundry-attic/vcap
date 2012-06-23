include_attribute "deployment"

default[:echo][:host] = "localhost"

default[:echo_node][:capacity] = "100"
default[:echo_node][:index] = "0"
default[:echo_node][:token] = "changeechotoken"

default[:echo_server][:id] = "eyJvaWQiOiI0ZTRlNzhiY2EzMWUxMjIyMDRlNGU5ODYzYjFiNzQwNGZlYmZk%0AZDE2OWI5ZCIsInNpZyI6Imx1Q1NmcVBlTS9rM0ZiUGl2RFhZMEVIbTRGOD0i%0AfQ==%0A"
default[:echo_server][:checksum] = "64de18e092c9faa52bf3dc3bf2b8f99562b4f2fe6509494f3d9252bce0cd5d81"
default[:echo_server][:path] = File.join(node[:deployment][:home], "deploy", "echoserver")
default[:echo_server][:port] = 5002
