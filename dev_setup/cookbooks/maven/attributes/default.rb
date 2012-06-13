include_attribute "deployment"
default[:maven][:version]  = "3.0.4"
default[:maven][:id]       = "eyJvaWQiOiI0ZTRlNzhiY2E2MWUxMjEwMDRlNGU3ZDUxZDk1MGUwNGZkNmMw%0AYWUxYmUyOCIsInNpZyI6IjNZREJHTEl5cWVVUExDbFJDMUUvNlFmd3J1TT0i%0AfQ==%0A"
default[:maven][:base]     = File.join(node[:deployment][:home], "deploy", "maven")
default[:maven][:path]     = File.join(node[:maven][:base], "apache-maven-#{maven[:version]}")
default[:maven][:checksum] = "d35a876034c08cb7e20ea2fbcf168bcad4dff5801abad82d48055517513faa2f"
