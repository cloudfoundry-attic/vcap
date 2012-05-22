include_attribute "deployment"
default[:ruby][:version] = "1.9.2-p180"
default[:ruby][:source]  = "http://ftp.ruby-lang.org//pub/ruby/1.9/ruby-#{ruby[:version]}.tar.gz"
default[:ruby][:path]    = File.join(node[:deployment][:home], "deploy", "rubies", "ruby-#{ruby[:version]}")
default[:ruby][:checksums]["1.9.2-p180"] = "9027a5abaaadc2af85005ed74aeb628ce2326441874bf3d4f1a842663cde04f4"

default[:rubygems][:version] = "1.8.24"
default[:rubygems][:bundler][:version] = "1.1.3"
default[:rubygems][:rake][:version] = "0.8.7"
default[:rubygems][:checksum] = "4b61fa51869b3027bcfe67184b42d2e8c23fa6ab17d47c5c438484b9be2821dd"
