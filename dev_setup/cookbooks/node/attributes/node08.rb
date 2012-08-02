include_attribute "deployment"
default[:node08][:version] = "0.8.2"
default[:node08][:path] = File.join(node[:deployment][:home], "deploy", "nodes", "node-#{node08[:version]}")
default[:node08][:id] = "eyJzaWciOiJJOTl4KzFWcUlLY3p6Sk0yTXVzaWZZUk5WS3c9Iiwib2lkIjoi%0ANGU0ZTc4YmNhNjFlMTIxMDA0ZTRlN2Q1MWQ5NTBlMDUwMThlZmJjZTA4MjIi%0AfQ==%0A"
default[:node][:checksums]["0.8.2"] = "6830ed4eaf6c191243fb3afbe3ca3283d7e3a537c8f3ce508fa2af1328fe4baf"
