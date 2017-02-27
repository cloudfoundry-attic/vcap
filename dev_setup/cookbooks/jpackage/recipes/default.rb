#
# Cookbook Name:: jpackage
# Recipe:: default
#
# Author: Ben Bleything <ben.bleything@livingsocial.com>
#

include_recipe "java"

case node[:platform]
when 'centos'
  cookbook_file "#{Chef::Config[:file_cache_path]}/jpackage-utils-5.0.0-2.jpp5.src.rpm" do
    mode "0644"
  end

  package "jpackage-utils" do
    source "#{Chef::Config[:file_cache_path]}/jpackage-utils-5.0.0-2.jpp5.src.rpm"
    action :install
  end
end

  # fix the jpackage-utils issue
  # https://bugzilla.redhat.com/show_bug.cgi?id=497213
  # http://plone.lucidsolutions.co.nz/linux/centos/jpackage-jpackage-utils-compatibility-for-centos-5.x
  # remote_file "#{Chef::Config[:file_cache_path]}/jpackage-utils-compat-el5-0.0.1-1.noarch.rpm" do
    # checksum "c61f2a97e4cda0781635310a6a595e978a2e48e64cf869df7d339f0db6a28093"
    # source "http://plone.lucidsolutions.co.nz/linux/centos/images/jpackage-utils-compat-el5-0.0.1-1.noarch.rpm"
    # mode "0644"
  # end
