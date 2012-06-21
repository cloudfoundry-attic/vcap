include_attribute "backup"
default[:mysql][:server_root_password] = "mysql"
default[:mysql][:server_root_user] = "root"
default[:mysql][:host] = "localhost"

default[:mysql_gateway][:service][:timeout] = "15"
default[:mysql_gateway][:node_timeout] = "2"

default[:mysql_node][:capacity] = "50"
default[:mysql_node][:index] = "0"
default[:mysql_node][:max_db_size] = "20"
default[:mysql_node][:token] = "changemysqltoken"
default[:mysql_node][:op_time_limit] = "6"
default[:mysql_node][:connection_wait_timeout] = "10"

default[:mysql_backup][:config_file] = "mysql_backup.yml"
default[:mysql_backup][:cron_time] = "0 1 * * *"
default[:mysql_backup][:cron_file] = "mysql_backup.cron"
