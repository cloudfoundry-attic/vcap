include_attribute "deployment"
default[:ruby18][:version] = "1.8.7-p334"
default[:ruby18][:source]  = "http://ftp.ruby-lang.org//pub/ruby/1.8/ruby-#{ruby18[:version]}.tar.gz"
default[:ruby18][:path]    = File.join(node[:deployment][:home], "deploy", "rubies", "ruby-#{ruby18[:version]}")
default[:ruby][:checksums]["1.8.7-p334"] = "68f68d6480955045661fab3be614c504bfcac167d070c6fdbfc9dbe2c5444bc0"
