include_attribute "deployment"
include_attribute "backup"
include_attribute "service_lifecycle"
include_attribute "service"

default[:mongodb][:path] = File.join(node[:service][:path], "mongodb")

default[:mongodb][:supported_versions] = {
        "1.8" => "1.8.5",
        "2.0" => "2.0.6"
}
default[:mongodb][:version_aliases] = {
        "current" => "1.8",
        "next"    => "2.0"
}

default[:mongod_options] = {
        "1.8" => "",
        "2.0" => "--nopreallocj"
}

default[:mongodb][:default_version] = "2.0"

default[:mongodb][:id] = {
        "1.8.5" => 'eyJzaWciOiJ0NHk5ZzBhRFkxSFZmaGhyNmQ5a0FQZFMxS1U9Iiwib2lkIjoi%0ANGU0ZTc4YmNhNTFlMTIxMjA0ZTRlODZlZThlMmM5MDUwMWEwZTYwOGI4YTMi%0AfQ==%0A',
        "2.0.6" => 'eyJzaWciOiJNTDBqWkJ6NjJ2cWNYWmVaZ3dsUENRWlhjbFE9Iiwib2lkIjoi%0ANGU0ZTc4YmNhNDFlMTIxMjA0ZTRlODZlZTUzOTIxMDUwMWEwZTg2M2IzNTgi%0AfQ==%0A'
}
default[:mongodb][:checksum] = {
        "1.8.5" => '0a84e0c749604cc5d523a8d8040beb0633ef8413ecd9e85b10190a30c568bb37',
        "2.0.6" => '26c09e81a67b15eb66260257665d801c55337a97a5fd028a474f5c194a986f18'
}

default[:mongodb_gateway][:service][:timeout] = "15"
default[:mongodb_gateway][:node_timeout] = "5"

default[:mongodb_node][:capacity] = "50"
default[:mongodb_node][:index] = "0"
default[:mongodb_node][:max_memory] = "128"
default[:mongodb_node][:token] = "changemongodbtoken"
default[:mongodb_node][:op_time_limit] = "6"
default[:mongodb_node][:mongo_timeout] = "2"

default[:mongodb_backup][:config_file] = "mongodb_backup.yml"
default[:mongodb_backup][:cron_time] = "0 5 * * *"
default[:mongodb_backup][:cron_file] = "mongodb_backup.cron"

default[:mongodb_worker][:config_file] = "mongodb_worker.yml"

default[:mongodb_proxy][:path] = File.join(default[:mongodb][:path], "mongodb_proxy")
default[:mongodb_proxy][:id][:yaml] = "eyJzaWciOiJSQjk2U251UDN2WFJMRmc0ZXdmenF2Q1czMnc9Iiwib2lkIjoi%0ANGU0ZTc4YmNhNTFlMTIyMDA0ZTRlOGVjNjg0MDc3MDUwZDE3NTgxNThjOGEi%0AfQ==%0A"
default[:mongodb_proxy][:id][:log4] = "eyJzaWciOiI3TXlRaXcvWERUckZWWmJvZWxBUWs0ejJaNlE9Iiwib2lkIjoi%0ANGU0ZTc4YmNhMjFlMTIxMDA0ZTRlN2Q1MTFmNTUzMDUwZDE3NThiMzg1YTAi%0AfQ==%0A"
default[:mongodb_proxy][:id][:mgo] = "eyJzaWciOiJSMHJINGh3cTRFUTBuZ2ZwcUExOHhuZ1pCNm89Iiwib2lkIjoi%0ANGU0ZTc4YmNhMjFlMTIyMDA0ZTRlOGVjNjQ3YTU0MDUwZDE3NTkzY2YwM2Mi%0AfQ==%0A"
default[:mongodb_proxy][:checksum][:yaml] = "558aa568d585bed6359f57bed5aeecd24276e98aa99c60e0a892eb2dfc27c4b2"
default[:mongodb_proxy][:checksum][:log4] = "1ff892e9ce4ea97cc143c8a802622361d55a8c6050a5c5687c4c602856e85cff"
default[:mongodb_proxy][:checksum][:mgo] = "775677639cdeda6e9818e6e387693be7c82c6592164a6dacc0e99f4f76451787"
