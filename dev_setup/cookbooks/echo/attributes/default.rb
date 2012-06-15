default[:echo][:host] = "localhost"

default[:echo_node][:capacity] = "100"
default[:echo_node][:index] = "0"
default[:echo_node][:token] = "changeechotoken"

default[:echo_server][:uri] = "https://github.com/downloads/jeffleefd/cf-echoserver/EchoServer-0.1.0.jar"
default[:echo_server][:path] = "/var/vcap/packages/echo/echoserver"
default[:echo_server][:name] = "EchoServer.jar"
default[:echo_server][:port] = 5002
