include_attribute "deployment"
default[:mongodb][:version] = "1.8.5"
default[:mongodb][:source] = "http://fastdl.mongodb.org/linux/mongodb-linux-#{node[:kernel][:machine]}-#{mongodb[:version]}.tgz"
default[:mongodb][:path] = File.join(node[:deployment][:home], "deploy", "mongodb")

default[:mongodb_node][:capacity] = "50"
default[:mongodb_node][:index] = "0"
default[:mongodb_node][:max_memory] = "128"
default[:mongodb_node][:token] = "changemongodbtoken"

# The checksums are for mongodb-1.8.1
if node[:kernel][:machine] == 'x86_64'
  default[:mongodb][:checksum] = '0a84e0c749604cc5d523a8d8040beb0633ef8413ecd9e85b10190a30c568bb37'
elsif node[:kernel][:machine] == 'i686'
  default[:mongodb][:checksum] = '24c6c7706ae2925b1a1b73241ca5a1de0812d32bc7927c939dbeebb045b929e5'
else
  Chef::Log.error("Installation of mongodb on #{node[:kernel][:machine]} is not supported")
end
