# Cookbook Name:: perl
#
# Recipe:: default
#
# Copyright 2012, VMware
case node['platform']
when "ubuntu"
  %w[
    perl perl-doc liblocal-lib-perl
  ].each {|pkg| package pkg }
