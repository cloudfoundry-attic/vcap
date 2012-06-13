include_attribute "deployment"
default[:mongodb][:version] = "1.8.1"
default[:mongodb][:path] = File.join(node[:deployment][:home], "deploy", "mongodb")

default[:mongodb_node][:capacity] = "50"
default[:mongodb_node][:index] = "0"
default[:mongodb_node][:max_memory] = "128"
default[:mongodb_node][:token] = "changemongodbtoken"

# The checksums are for mongodb-1.8.1
if node[:kernel][:machine] == 'x86_64'
  default[:mongodb][:id] = 'eyJvaWQiOiI0ZTRlNzhiY2E1MWUxMjEwMDRlNGU3ZDUxOTA2Y2QwNGYzMDY4%0AOTMzYjdjOSIsInNpZyI6Im5FdHp2akZZZ0lIRW9tOFUzSENyNHJJYXBhQT0i%0AfQ==%0A'
  default[:mongodb][:checksum] = '8f6a58293068e0fb28b463b955f3660f492094e53129fb88af4a7efcfc7995da'
elsif node[:kernel][:machine] == 'i686'
  default[:mongodb][:id] = 'eyJvaWQiOiI0ZTRlNzhiY2EyMWUxMjIwMDRlNGU4ZWM2NDdhNTQwNGYzMDY4%0AODI1M2IyMSIsInNpZyI6Ijl2M2FEREpNNnpobTZ0bGV1bUwvMlZKeDlLMD0i%0AfQ==%0A'
  default[:mongodb][:checksum] = '19415154974d62e745977e1bc01e24c0ca3b9d1149881da255315fb4f1cfbf31'
else
  Chef::Log.error("Installation of mongodb on #{node[:kernel][:machine]} is not supported")
end
