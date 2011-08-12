#
# Cookbook Name:: essentials
# Recipe:: default
#
# Copyright 2011, VMWARE
#
# All rights reserved - Do Not Redistribute
#
%w{apt-utils wget curl libcurl3 bison build-essential zlib1g-dev libssl-dev
   libreadline5-dev libxml2 libxml2-dev libxslt1.1 libxslt1-dev git-core sqlite3 libsqlite3-ruby
   libsqlite3-dev unzip zip ruby-dev libmysql-ruby libmysqlclient-dev libcurl4-openssl-dev}.each do |p|
  package p do
    action [:install]
  end
end
