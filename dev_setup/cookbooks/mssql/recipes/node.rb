#
# Cookbook Name:: gateway
# Recipe:: default
#
#

cloudfoundry_service "mssql" do
  components ["mssql_node"]
end
