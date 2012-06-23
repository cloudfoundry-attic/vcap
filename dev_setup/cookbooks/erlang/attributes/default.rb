include_attribute "deployment"
default[:erlang][:version] = "R14B01"
default[:erlang][:id] = "eyJvaWQiOiI0ZTRlNzhiY2E2MWUxMjIyMDRlNGU5ODY0M2Q5YWUwNGYzMDVi%0AMmE2MjE5ZSIsInNpZyI6IkwxVWFhWEhmWGtIRmR4Z0tUMHdqRkpTNjRQZz0i%0AfQ==%0A"
default[:erlang][:path] = File.join(node[:deployment][:home], "deploy", "erlang")
default[:erlang][:checksum] = "88349fa9f112e21b09726434ee5f4013d3ed3fb1d0f2623f22689dc20886f2f8"
