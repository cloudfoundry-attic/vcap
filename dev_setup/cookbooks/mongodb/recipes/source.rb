#
# Cookbook Name:: mongodb
# Recipe:: source
#
# Author:: Gerhard Lazu (<gerhard.lazu@papercavalier.com>)
#
# Copyright 2010, Paper Cavalier, LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
platform = node[:kernel][:machine]

mongodb_path = node[:mongodb][:dir]

user "mongodb" do
  comment "MongoDB Administrator"
  system true
  shell "/bin/false"
end

[mongodb_path, "#{mongodb_path}/bin"].each do |dir|
  directory dir do
    owner node[:mongodb][:user]
    group node[:mongodb][:group]
    mode "0755"
    recursive true
  end
end

unless `ps -A -o command | grep "[m]ongo"`.include? node[:mongodb][:version]
  # ensuring we have this directory
  directory "/tmp"

  remote_file "/tmp/mongodb-#{node[:mongodb][:version]}.tar.gz" do
    source node[:mongodb][:source]
    checksum node[:mongodb][platform][:checksum]
    owner node[:mongodb][:user]
    action :create_if_missing
  end

  bash "Setting up MongoDB #{node[:mongodb][:version]}" do
    cwd "/tmp"
    user node[:mongodb][:user]
    code <<-EOH
      tar -zxf mongodb-#{node[:mongodb][:version]}.tar.gz --strip-components=2 -C #{mongodb_path}/bin
    EOH
  end
end

environment = File.read('/etc/environment')
unless environment.include? mongodb_path
  File.open('/etc/environment', 'w') { |f| f.puts environment.gsub(/PATH="/, "PATH=\"#{mongodb_path}/bin:") }
end

node[:mongodb][:installed_from] = "src"
