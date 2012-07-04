default[:service_lifecycle][:enable] = false
default[:service_lifecycle][:max_upload_size] = 5
default[:service_lifecycle][:tmp_dir] = "/tmp"
default[:snapshot][:dir]="/var/vcap/snapshot"
default[:snapshot_manager][:config_file]="snapshot_manager.yml"
default[:snapshot_manager][:cleanup_max_days] = "3"
default[:snapshot_manager][:greedy_mark] = false
default[:snapshot_manager][:wakeup_interval_in_sec] = "3600"

default[:redis_resque][:host]= "localhost"
default[:redis_resque][:port] = 4999
default[:redis_resque][:password] = "redis"
default[:redis_resque][:expire] = 60

default[:serialization_data_server][:config_file]="serialization_data_server.yml"
