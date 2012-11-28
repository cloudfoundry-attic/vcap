cf_ruby_install(node[:ruby18][:version], node[:ruby18][:id], node[:ruby18][:path], "bz2")

cf_rubygems_install(node[:ruby18][:path], node[:rubygems][:version], node[:rubygems][:id], node[:rubygems][:checksum])
cf_gem_install(node[:ruby18][:path], "bundler", node[:ruby][:bundler][:version])
cf_gem_install(node[:ruby18][:path], "rake", node[:ruby18][:rake][:version])

%w[ rack eventmachine thin sinatra mysql pg vmc ].each {|gem| cf_gem_install(node[:ruby18][:path], gem)}
