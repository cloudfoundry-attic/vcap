include_attribute "deployment"
default[:erlang][:version] = "R14B01"
default[:erlang][:id] = "eyJzaWciOiJhYmhYc0hsTERyNVpJc2Q5Y3pibTdMZy9kTUk9Iiwib2lkIjoi%0ANGU0ZTc4YmNhMzFlMTIyMjA0ZTRlOTg2M2IxYjc0MDUwMThlZDMzZDNlMDIi%0AfQ==%0A"
default[:erlang][:path] = File.join(node[:deployment][:home], "deploy", "erlang")
default[:erlang][:checksum] = "88349fa9f112e21b09726434ee5f4013d3ed3fb1d0f2623f22689dc20886f2f8"
