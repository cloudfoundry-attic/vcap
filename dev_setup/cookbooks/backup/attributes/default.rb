default[:backup][:enable] = true
default[:backup][:dir]="/var/vcap/backup"
default[:backup_manager][:config_file]="backup_manager.yml"
default[:backup_manager][:rotation_max_days] = "7"
default[:backup_manager][:wakeup_interval_in_sec] = "43200"

