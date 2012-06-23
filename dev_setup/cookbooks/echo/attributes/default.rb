default[:echo][:host] = "localhost"

default[:echo_node][:capacity] = "100"
default[:echo_node][:index] = "0"
default[:echo_node][:token] = "changeechotoken"

default[:echo_server][:uri] = "https://github.com/downloads/jeffleefd/cf-echoserver/echoserver.zip"
default[:echo_server][:archive] = "echoserver.zip"
default[:echo_server][:path] = "/var/vcap/packages/echo/"
default[:echo_server][:name] = "echoserver"
default[:echo_server][:port] = 5002
