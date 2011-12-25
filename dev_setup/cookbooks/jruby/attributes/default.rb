include_attribute "deployment"
default[:jruby][:version] = "1.6.5"
default[:jruby][:ruby_version] = "1.8.7p330"
default[:jruby][:source_archive]  = "jruby-src-#{node[:jruby][:version]}.tar.gz"
default[:jruby][:source_url]  = "http://jruby.org.s3.amazonaws.com/downloads/#{node[:jruby][:version]}/#{node[:jruby][:source_archive]}"

default[:jruby][:ant_name]  = "apache-ant-1.8.2"
default[:jruby][:ant_binary_archive]  = "#{node[:jruby][:ant_name]}-bin.tar.gz"
default[:jruby][:ant_binary_url]  = "http://archive.apache.org/dist/ant/binaries/#{node[:jruby][:ant_binary_archive]}"

default[:jruby][:path]    = File.join(node[:deployment][:home], "deploy", "rubies", "jruby-#{node[:jruby][:version]}")
default[:jruby][:ruby_engine] = "jruby"
default[:jruby][:library_version] = "1.8"

default[:rubygems][:version] = "1.8.7"
default[:rubygems][:bundler][:version] = "1.0.18"
default[:rubygems][:rake][:version] = "0.8.7"
