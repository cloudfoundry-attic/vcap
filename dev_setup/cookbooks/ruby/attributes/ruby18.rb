include_attribute "deployment"
default[:ruby18][:version] = "1.8.7-p357"
default[:ruby18][:id] = "eyJvaWQiOiI0ZTRlNzhiY2ExMWUxMjEyMDRlNGU4NmVlMTUyOTQwNGYzMDcx%0ANDUzZGFmZiIsInNpZyI6IkFhZCt6VlRiMDd1dVBMa24vZFh2SnVHVUtldz0i%0AfQ==%0A"
default[:ruby18][:path] = File.join(node[:deployment][:home], "deploy", "rubies", "ruby-#{ruby18[:version]}")
default[:ruby][:checksums]["1.8.7-p357"] = "5c64b63a597b4cb545887364e1fd1e0601a7aeb545e576e74a6d8e88a2765a37"
