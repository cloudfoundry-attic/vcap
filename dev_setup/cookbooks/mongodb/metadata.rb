maintainer        "Paper Cavalier"
maintainer_email  "code@papercavalier.com"
license           "Apache 2.0"
description       "Installs and configures MongoDB 1.8.1"
version           "1.8.1"

recipe "mongodb", "Default recipe simply includes the mongodb::source and mongodb::server recipes"
recipe "mongodb::apt", "Installs MongoDB from 10Gen's apt source and includes init.d script"
recipe "mongodb::backup", "Sets up MongoDB backup script, taken from http://github.com/micahwedemeyer/automongobackup"
recipe "mongodb::config_server", "Sets up config and initialization to run mongod as a config server for sharding"
recipe "mongodb::mongos", "Sets up config and initialization to run mongos, the MongoDB sharding router"
recipe "mongodb::server", "Set up config and initialization to run mongod as a database server"
recipe "mongodb::source", "Installs MongoDB from source and includes init.d script"

%w{ ubuntu debian }.each do |os|
  supports os
end

# Package info
attribute "mongodb/version",
  :display_name => "MongoDB source version",
  :description => "Which MongoDB version will be installed from source",
  :recipes => ["mongodb::source"],
  :default => "1.8.1"

attribute "mongodb/source",
  :display_name => "MongoDB source file",
  :description => "Downloaded location for MongoDB",
  :recipes => ["mongodb::source"],
  :calculated => true

attribute "mongodb/i686/checksum",
  :display_name => "MongoDB 32bit source file checksum",
  :description => "Will make sure the source file is the real deal",
  :recipes => ["mongodb::source"],
  :default => "7970858350cda1f3eed4b967e67a64f8"

attribute "mongodb/x86_64/checksum",
  :display_name => "MongoDB 64bit source file checksum",
  :description => "Will make sure the source file is the real deal",
  :recipes => ["mongodb::source"],
  :default => "58ebc4c9e1befd9847029592011fb9ed"
