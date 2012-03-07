include_attribute "deployment"
default[:node06][:version] = "0.6.8"
default[:node06][:path] = File.join(node[:deployment][:home], "deploy", "nodes", "node-#{node06[:version]}")
default[:node06][:source] = "http://nodejs.org/dist/v#{node06[:version]}/node-v#{node06[:version]}.tar.gz"
