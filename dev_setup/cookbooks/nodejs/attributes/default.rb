include_attribute "deployment"
default[:nodejs][:version] = "0.4.8"
default[:nodejs][:path] = File.join(node[:deployment][:home], "deploy", "nodejs")
default[:nodejs][:source] = "http://nodejs.org/dist/node-v#{nodejs[:version]}.tar.gz"
