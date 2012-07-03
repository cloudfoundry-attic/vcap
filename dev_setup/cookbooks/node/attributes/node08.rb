include_attribute "deployment"
default[:node08][:version] = "0.8.2"
default[:node08][:path] = File.join(node[:deployment][:home], "deploy", "nodes", "node-#{node08[:version]}")
default[:node08][:id] = "eyJvaWQiOiI0ZTRlNzhiY2E2MWUxMjIyMDRlNGU5ODY0M2Q5YWUwNGZmYjVk%0AOTY1MWJhMCIsInNpZyI6ImpQUzhLRTFOWE5XbENkYnhUbjlPQU9wQ3JJbz0i%0AfQ==%0A"
default[:node][:checksums]["0.8.2"] = "6830ed4eaf6c191243fb3afbe3ca3283d7e3a537c8f3ce508fa2af1328fe4baf"
