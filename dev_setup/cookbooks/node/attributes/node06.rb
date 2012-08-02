include_attribute "deployment"
default[:node06][:version] = "0.6.8"
default[:node06][:path] = File.join(node[:deployment][:home], "deploy", "nodes", "node-#{node06[:version]}")
default[:node06][:id] = "eyJzaWciOiJzM0FEVVlkNVRGd2xFdTN4UzAxNlYzZWtYTHM9Iiwib2lkIjoi%0ANGU0ZTc4YmNhMzFlMTIyMDA0ZTRlOGVjNjQ2ZTIxMDUwMThlZmI1NDQ3YTQi%0AfQ==%0A"
default[:node][:checksums]["0.6.8"] = "e6cbfc5ccdbe10128dbbd4dc7a88c154d80f8a39c3a8477092cf7d25eef78c9c"
