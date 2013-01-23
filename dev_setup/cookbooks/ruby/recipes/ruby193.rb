cf_ruby_install(node[:ruby193][:version], node[:ruby193][:id], node[:ruby193][:path], "gz")

# Ruby 1.9.3 installs Rake 0.9.2.2, so just install Bundler and upgrade Rubygems
cf_rubygems_install(node[:ruby193][:path], node[:rubygems][:version], node[:rubygems][:id], node[:rubygems][:checksum])
cf_gem_install(node[:ruby193][:path], "bundler", node[:ruby][:bundler][:version])

%w[ rack eventmachine thin sinatra mysql pg vmc ].each {|gem| cf_gem_install(node[:ruby193][:path], gem)}
