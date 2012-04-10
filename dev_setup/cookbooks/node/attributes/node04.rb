include_attribute "deployment"
default[:node04][:version] = "0.4.12"
default[:node04][:path] = File.join(node[:deployment][:home], "deploy", "nodes", "node-#{node04[:version]}")
default[:node04][:source] = "http://nodejs.org/dist/node-v#{node04[:version]}.tar.gz"
