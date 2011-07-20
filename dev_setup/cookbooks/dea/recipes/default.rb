#
# Cookbook Name:: dea
# Recipe:: default
#
# Copyright 2011, VMWARE
#
# All rights reserved - Do Not Redistribute
#
%w{lsof psmisc librmagick-ruby}.each do |pkg|
  package pkg
end
