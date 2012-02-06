include_attribute "deployment"
default[:ruby][:version] = "1.9.2-p290"
default[:ruby][:source]  = "http://ftp.ruby-lang.org//pub/ruby/1.9/ruby-#{ruby[:version]}.tar.gz"
default[:ruby][:path]    = File.join(node[:deployment][:home], "deploy", "rubies", "ruby-#{ruby[:version]}")

default[:rubygems][:version] = "1.8.7"
default[:rubygems][:bundler][:version] = "1.0.18"
default[:rubygems][:rake][:version] = "0.8.7"
