#
# Cookbook Name:: mongodb
# Recipe:: mongos
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

config_db_nodes = search(:node, 'recipes:mongodb\:\:config_server')

# must have either one or three config dbs
if config_db_nodes.length == 2
  config_db_nodes.pop
else
  config_db_nodes = config_db_nodes[0..2]
end

init_variables = { :configdb_server_list => config_db_nodes.collect { |n| "#{n[:mongodb][:config_server][:bind_ip]}:#{n[:mongodb][:config_server][:port]}" }.join(',') }
mongodb_process(:mongos, :init => init_variables)
