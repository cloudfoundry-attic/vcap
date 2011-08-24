include_attribute "deployment"
default[:erlang][:version] = "R14B02"
default[:erlang][:source]  = "http://erlang.org/download/otp_src_#{erlang[:version]}.tar.gz"
default[:erlang][:path]    = File.join(node[:deployment][:home], "deploy", "erlang")
