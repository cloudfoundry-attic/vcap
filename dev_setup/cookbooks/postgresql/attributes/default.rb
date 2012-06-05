include_attribute "backup"
include_attribute "service_lifecycle"

default[:postgresql][:server_root_password] = "changeme"
default[:postgresql][:server_root_user] = "root"
default[:postgresql][:system_port] = "5432"
default[:postgresql][:service_port] = "5433"
default[:postgresql][:system_version] = "8.4"
default[:postgresql][:service_version] = "9.0"

default[:postgresql_gateway][:service][:timeout] = "15"
default[:postgresql_gateway][:node_timeout] = "10"

default[:postgresql_node][:host] = "localhost"
default[:postgresql_node][:database] = "pg_service"
default[:postgresql_node][:capacity] = "50"
default[:postgresql_node][:max_db_size] = "20"
default[:postgresql_node][:token] = "changepostgresqltoken"
default[:postgresql_node][:index] = "0"
default[:postgresql_node][:op_time_limit] = "6"

default[:postgresql_backup][:config_file] = "postgresql_backup.yml"
default[:postgresql_backup][:cron_time] = "0 2 * * *"
default[:postgresql_backup][:cron_file] = "postgresql_backup.cron"

default[:postgresql_worker][:config_file] = "postgresql_worker.yml"
