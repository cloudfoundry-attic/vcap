default[:nodejs][:version] = "0.4.7"
default[:nodejs][:path] = "/var/vcap/deploy/nodejs"
default[:nodejs][:source] = "http://nodejs.org/dist/node-v#{nodejs[:version]}.tar.gz"
