#
# Cookbook Name:: mongodb
# Recipe:: apt
#
# Author:: Michael Shapiro (<koudelka@ryoukai.org>)
#
# Copyright 2011, Active Prospect, Inc.
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

execute "apt-get update" do
  action :nothing
end

execute "add 10gen apt key" do
  command "apt-key adv --keyserver keyserver.ubuntu.com --recv 7F0CEB10"
  action :nothing
end

template "/etc/apt/sources.list.d/mongodb.list" do
  owner "root"
  mode "0644"
  source "mongodb.list.erb"
  notifies :run, resources(:execute => "add 10gen apt key"), :immediately
  notifies :run, resources(:execute => "apt-get update"), :immediately
end

package "mongodb-10gen"

node[:mongodb][:installed_from] = "apt"
