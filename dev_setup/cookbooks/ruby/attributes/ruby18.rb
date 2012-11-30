include_attribute "deployment"
default[:ruby18][:version] = "1.8.7-p357"
default[:ruby18][:id] = "eyJzaWciOiJTWTE5cWxwNnQybkIyNUJxUTl4YUo5bXNZVE09Iiwib2lkIjoi%0ANGU0ZTc4YmNhNjFlMTIyMDA0ZTRlOGVjNmI0NGI2MDUwMTlmMzM5MWE4NDEi%0AfQ==%0A"
default[:ruby18][:path] = File.join(node[:deployment][:home], "deploy", "rubies", "ruby-#{ruby18[:version]}")
default[:ruby][:checksums]["1.8.7-p357"] = "5c64b63a597b4cb545887364e1fd1e0601a7aeb545e576e74a6d8e88a2765a37"
default[:ruby18][:rake][:version] = "0.8.7"
