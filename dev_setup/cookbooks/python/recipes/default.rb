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

bash "Installing pip" do
  code "sudo easy_install pip"
end
