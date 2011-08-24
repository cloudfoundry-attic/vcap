include_attribute "deployment"
default[:ruby18][:version] = "1.8.7-p334"
default[:ruby18][:source]  = "http://ftp.ruby-lang.org//pub/ruby/1.8/ruby-#{ruby18[:version]}.tar.gz"
default[:ruby18][:path]    = File.join(node[:deployment][:home], "deploy", "rubies", "ruby-#{ruby18[:version]}")
