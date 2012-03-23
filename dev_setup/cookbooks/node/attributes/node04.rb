include_attribute "deployment"
default[:node04][:version] = "0.4.12"
default[:node04][:path] = File.join(node[:deployment][:home], "deploy", "nodes", "node-#{node04[:version]}")
default[:node04][:source] = "http://nodejs.org/dist/node-v#{node04[:version]}.tar.gz"

default[:node04][:npm][:version] = "1.0.106"
default[:node04][:npm][:source] = "http://registry.npmjs.org/npm/-/npm-#{node[:node04][:npm][:version]}.tgz"
default[:node04][:npm][:path] = File.join(node[:deployment][:home], "deploy", "nodes", "npm-#{node[:node04][:npm][:version]}")
