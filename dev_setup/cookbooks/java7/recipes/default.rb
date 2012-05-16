#
# Cookbook Name:: java7
# Recipe:: default
#
# Copyright 2011, VMware
#
#

case node['platform']
when "ubuntu"
#  package 'default-jdk'
# FIXME: add other major distro support

  java7_version = node[:java7][:version]
  java7_version_flag = node[:java7][:version_flag]
  java7_oracle_path = node[:java7][:oracle_home] + "/" + node[:java7][:jre_path]
  java7_openjdk_path = node[:java7][:openjdk_home] + "/" + node[:java7][:jre_path]

  Chef::Log.info("Support for Java 7 requires that a local build of OpenJDK 7 or Oracle JDK 7 is available.")
  java7_path = java7_openjdk_path
  java7_exec = java7_path + "/" + node[:java7][:exec]
  expanded_exec = `which #{java7_exec}`
  unless $? == 0
    Chef::Log.info("An installation of OpenJDK 7 was not found at the required location of #{node[:java7][:openjdk_home]}")
    Chef::Log.info("Will now search for Oracle JDK 7")
    java7_path = java7_oracle_path
    node[:java7][:java_home] = node[:java7][:oracle_home]
  end

  java7_exec = java7_path + "/" + node[:java7][:exec]
  expanded_exec = `which #{java7_exec}`
  unless $? == 0
    Chef::Log.info("An installation of OpenJDK 7 or Oracle JDK 7 was not found.")
    Chef::Log.info("Java 7 support will be disabled.")
  else
    expanded_exec.strip!
    version_check = `env -i HOME=$HOME #{expanded_exec} #{java7_version_flag} 2>&1`.strip!
    unless $? == 0
      Chef::Log.info("Failed to obtain version for #{expanded_exec}")
      Chef::Log.info("Java 7 support will be disabled.")
    else
      if /#{java7_version}/ =~ version_check
        Chef::Log.info("Found a compatible Java 7 installation, Java 7 support will be enabled.")
        node[:java7][:path] = java7_path
        node[:java7][:available?] = true
      else
        Chef::Log.info("Expected a Java version containing #{java7_version} - got: #{version_check}")
        Chef::Log.info("Java 7 support will be disabled.")
      end
    end
  end
else
  Chef::Log.error("Installation of OpenJDK 7 not supported on this platform.")
end
