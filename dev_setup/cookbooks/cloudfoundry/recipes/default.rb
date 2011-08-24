#
# Cookbook Name:: cloudfoundry
# Recipe:: default
#
# Copyright 2011, VMWare
#
#

# Gem packages have transient failures, so ignore failures
gem_package "vmc" do
  ignore_failure true
  gem_binary File.join(node[:ruby][:path], "bin", "gem")
end
