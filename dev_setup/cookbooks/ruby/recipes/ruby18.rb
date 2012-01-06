# convenience variables
ruby_version = node[:ruby18][:version]
ruby_source = node[:ruby18][:source]
ruby_path = node[:ruby18][:path]

cf_ruby_install(ruby_version, ruby_source, ruby_path)
