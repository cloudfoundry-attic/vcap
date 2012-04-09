include_attribute "deployment"
default[:node04][:version] = "0.4.12"
default[:node04][:path] = File.join(node[:deployment][:home], "deploy", "nodes", "node-#{node04[:version]}")
default[:node04][:source] = "http://nodejs.org/dist/node-v#{node04[:version]}.tar.gz"

default[:node][:checksums]["0.4.12"] = "c01af05b933ad4d2ca39f63cac057f54f032a4d83cff8711e42650ccee24fce4"
