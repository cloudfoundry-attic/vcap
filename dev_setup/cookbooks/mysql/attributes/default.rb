include_attribute "backup"
include_attribute "service_lifecycle"
include_attribute "service"

default[:mysql][:default_version] = "5.5"

default[:mysql][:path] = File.join(node[:service][:path], "mysql")

default[:mysql][:id][:server] = "eyJzaWciOiJNeTJsYkFDMk4xcnphZTM1ejBXV2ltbFhGOWs9Iiwib2lkIjoi%0ANGU0ZTc4YmNhNjFlMTIyMDA0ZTRlOGVjNmI0NGI2MDUwZDJhOGFlNGMyOTki%0AfQ==%0A"
default[:mysql][:id][:client] = "eyJzaWciOiI1eEhUaWdmTU1vSFBzamZkZGM4ZWxZaWZwKzA9Iiwib2lkIjoi%0ANGU0ZTc4YmNhMzFlMTIyMDA0ZTRlOGVjNjQ2ZTIxMDUwZDJhODhkNTQyOWYi%0AfQ==%0A"
default[:mysql][:id][:initdb] = "eyJzaWciOiJMZ3cvVVN4YllhMDhUS3c3U1g4R0REeEVyUlk9Iiwib2lkIjoi%0ANGU0ZTc4YmNhNDFlMTIxMDA0ZTRlN2Q1MTc2MThmMDUwZDJhOGExMmYxYzci%0AfQ==%0A"

default[:mysql][:checksum][:server] = "34197617ccd74cd7e8bd639fb8b168172bf3bd0b48de9d9e567b535a315b89e8"
default[:mysql][:checksum][:client] = "6c758ca82eeeb3e746cdffa03e1a0f28e51befd248e2e9a5fc1477b287f0d52c"
default[:mysql][:checksum][:initdb] = "fd13b9586c4dfbc8a06c4d0240dca887fd748f6a4f80f74b445271a700976a66"

default[:mysql][:server_root_password] = "mysql"
default[:mysql][:server_root_user] = "root"
default[:mysql][:host] = "localhost"

default[:mysql_gateway][:service][:timeout] = "25"
default[:mysql_gateway][:node_timeout] = "20"

default[:mysql_node][:capacity] = "50"
default[:mysql_node][:index] = "0"
default[:mysql_node][:max_db_size] = "20"
default[:mysql_node][:token] = "changemysqltoken"
default[:mysql_node][:op_time_limit] = "15"
default[:mysql_node][:connection_wait_timeout] = "10"

default[:mysql_backup][:config_file] = "mysql_backup.yml"
default[:mysql_backup][:cron_time] = "0 1 * * *"
default[:mysql_backup][:cron_file] = "mysql_backup.cron"

default[:mysql_worker][:config_file] = "mysql_worker.yml"
