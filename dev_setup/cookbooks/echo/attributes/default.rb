include_attribute "deployment"

default[:echo][:host] = "localhost"

default[:echo_node][:capacity] = "100"
default[:echo_node][:index] = "0"
default[:echo_node][:token] = "changeechotoken"

default[:echo_server][:id] = "eyJvaWQiOiI0ZTRlNzhiY2ExMWUxMjEwMDRlNGU3ZDUxMWY4MjEwNTAwOTA0%0ANGIxMDRkMCIsInNpZyI6Ikd2RFlpUlh2bEhrdnoxT3pyTVJhYlhUcjJyMD0i%0AfQ==%0A"
default[:echo_server][:checksum] = "a4d5976dfff5d0c9e14fd6eaaa587fcc2543f18c88e3f28960cd18d04c1fa7c9"
default[:echo_server][:path] = File.join(node[:deployment][:home], "deploy", "echoserver")
default[:echo_server][:port] = 5002
