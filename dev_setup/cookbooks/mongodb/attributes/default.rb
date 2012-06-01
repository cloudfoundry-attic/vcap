include_attribute "deployment"
default[:mongodb][:version] = "1.8.1"
default[:mongodb][:source] = "http://fastdl.mongodb.org/linux/mongodb-linux-#{node[:kernel][:machine]}-#{mongodb[:version]}.tgz"
default[:mongodb][:path] = File.join(node[:deployment][:home], "deploy", "mongodb")

default[:mongodb_node][:capacity] = "50"
default[:mongodb_node][:index] = "0"
default[:mongodb_node][:max_memory] = "128"
default[:mongodb_node][:token] = "changemongodbtoken"

# The checksums are for mongodb-1.8.1
if node[:kernel][:machine] == 'x86_64'
  default[:mongodb][:checksum] = '8f6a58293068e0fb28b463b955f3660f492094e53129fb88af4a7efcfc7995da'
elsif node[:kernel][:machine] == 'i686'
  default[:mongodb][:checksum] = '19415154974d62e745977e1bc01e24c0ca3b9d1149881da255315fb4f1cfbf31'
else
  Chef::Log.error("Installation of mongodb on #{node[:kernel][:machine]} is not supported")
end
