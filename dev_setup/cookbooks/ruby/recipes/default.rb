# convenience variables
ruby_version = node[:ruby][:version]
ruby_source = node[:ruby][:source]
ruby_path = node[:ruby][:path]

cf_ruby_install(ruby_version, ruby_source, ruby_path)
