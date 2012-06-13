include_attribute "deployment"
default[:node04][:version] = "0.4.12"
default[:node04][:path] = File.join(node[:deployment][:home], "deploy", "nodes", "node-#{node04[:version]}")
default[:node04][:id] = "eyJvaWQiOiI0ZTRlNzhiY2E2MWUxMjEwMDRlNGU3ZDUxZDk1MGUwNGYzMDY4%0ANzYwZjY3ZiIsInNpZyI6ImI2clVsYnpCbFllWGhOMjUwbSt4Tmk2S2pVTT0i%0AfQ==%0A"

default[:node04][:npm][:version] = "1.0.106"
default[:node04][:npm][:id] = "eyJvaWQiOiI0ZTRlNzhiY2ExMWUxMjIwMDRlNGU4ZWM2NDg0MzEwNGY2NmFj%0AMDdjNjdiZCIsInNpZyI6IkhrR0RjWUFrdU94MFJBaGZlTVJTYlk0dFVBWT0i%0AfQ==%0A"
default[:node04][:npm][:path] = File.join(node[:deployment][:home], "deploy", "nodes", "npm-#{node[:node04][:npm][:version]}")
default[:node04][:npm][:checksum] = "bab33e420e4c00be550d7933fbc328daa07b437fa458149bc4a0da84cc82a5b4"

default[:node][:checksums]["0.4.12"] = "c01af05b933ad4d2ca39f63cac057f54f032a4d83cff8711e42650ccee24fce4"
