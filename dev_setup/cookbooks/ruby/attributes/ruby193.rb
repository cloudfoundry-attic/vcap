include_attribute "deployment"

default[:ruby193][:version] = "1.9.3-p194"
default[:ruby193][:id] = "eyJvaWQiOiI0ZTRlNzhiY2EzMWUxMjEyMDRlNGU4NmVlMzk2OTIwNTA3NWUx%0AMjdhZGIwMSIsInNpZyI6InY5d0FVYnZsNzFONStnU2Z3NUN6YVVWNFNHWT0i%0AfQ==%0A"

default[:ruby193][:path]    = File.join(node[:deployment][:home], "deploy", "rubies", "ruby-#{ruby193[:version]}")
default[:ruby][:checksums]["1.9.3-p194"] = "46e2fa80be7efed51bd9cdc529d1fe22ebc7567ee0f91db4ab855438cf4bd8bb"
