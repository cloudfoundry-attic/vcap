#
# Cookbook Name:: python
# Recipe:: default
#
# Copyright 2012, VMware
#
#

%w[ python-dev python-setuptools ].each do |pkg|
  package pkg
end

# Add -E for http_proxy use
bash "Installing pip" do
  code "sudo -E easy_install pip"
end
