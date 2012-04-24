include_attribute "deployment"
default[:node06][:version] = "0.6.8"
default[:node06][:path] = File.join(node[:deployment][:home], "deploy", "nodes", "node-#{node06[:version]}")
default[:node06][:source] = "http://nodejs.org/dist/v#{node06[:version]}/node-v#{node06[:version]}.tar.gz"

default[:node][:checksums]["0.6.8"] = "e6cbfc5ccdbe10128dbbd4dc7a88c154d80f8a39c3a8477092cf7d25eef78c9c"
