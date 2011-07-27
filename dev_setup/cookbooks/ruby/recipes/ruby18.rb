orig_version = node[:ruby][:version]
orig_source = node[:ruby][:source]
orig_path = node[:ruby][:path]

node[:ruby][:version] = node[:ruby18][:version]
node[:ruby][:source] = node[:ruby18][:source]
node[:ruby][:path] = node[:ruby18][:path]

include_recipe "ruby::default"

node[:ruby][:version] = orig_version
node[:ruby][:source] = orig_source
node[:ruby][:path] = orig_path
