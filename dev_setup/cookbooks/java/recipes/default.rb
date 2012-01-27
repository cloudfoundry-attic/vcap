#
# Cookbook Name:: java
# Recipe:: default
#
# Copyright 2011, VMware
#
#
package "python-software-properties"

case node['platform']
when "ubuntu"
  bash "Setup java" do
    code <<-EOH
    add-apt-repository "deb http://archive.canonical.com/ lucid partner"
    apt-get -qqy update
    echo sun-java6-jdk shared/accepted-sun-dlj-v1-1 boolean true | /usr/bin/debconf-set-selections
    echo sun-java6-jre shared/accepted-sun-dlj-v1-1 boolean true | /usr/bin/debconf-set-selections
    EOH
    not_if "grep -q '^deb .* lucid partner' /etc/apt/sources.list"
  end

  %w[ sun-java6-jdk sun-java6-source ].each do |pkg|
    package pkg
  end

else
  Chef::Log.error("Installation of Sun Java packages not supported on this platform.")
end
