### SOURCE PACKAGES
default[:mongodb][:version]           = "1.8.1"
default[:mongodb][:source]            = "http://fastdl.mongodb.org/linux/mongodb-linux-#{node[:kernel][:machine]}-#{mongodb[:version]}.tgz"
default[:mongodb][:i686][:checksum]   = "7970858350cda1f3eed4b967e67a64f8"
default[:mongodb][:x86_64][:checksum] = "58ebc4c9e1befd9847029592011fb9ed"

# we'll be re-using this across all server type configs
if node[:network][:interfaces][:eth0]
  bind_ip = node[:network][:interfaces][:eth0][:addresses].select do |address, values|
    values['family'] == 'inet'
  end.first.first
else
  bind_ip = "0.0.0.0"
end

##########################################################################
### MAIN SERVER

### GENERAL
default[:mongodb][:server][:bind_ip]               = bind_ip
default[:mongodb][:server][:config]                = "/etc/mongodb.conf"
default[:mongodb][:server][:dbpath]                = "/var/lib/mongodb"
default[:mongodb][:server][:dir]                   = "/opt/mongodb-#{mongodb[:version]}"
default[:mongodb][:dir]                            = "/opt/mongodb-#{mongodb[:version]}"
default[:mongodb][:user]                           = "mongodb"
default[:mongodb][:group]                          = "mongodb"
default[:mongodb][:server][:logpath]               = "/var/log/mongodb.log"
default[:mongodb][:server][:pidfile]               = "/var/lib/mongodb/mongod.lock"
default[:mongodb][:server][:port]                  = 27017
default[:mongodb][:server][:system_init]           = "sysv"

### EXTRA
default[:mongodb][:server][:auth]                  = false
default[:mongodb][:server][:cpu]                   = false
default[:mongodb][:server][:diaglog]               = false
default[:mongodb][:server][:logappend]             = true
default[:mongodb][:server][:nocursors]             = false
default[:mongodb][:server][:nohints]               = false
default[:mongodb][:server][:nohttpinterface]       = false
default[:mongodb][:server][:noscripting]           = false
default[:mongodb][:server][:notablescan]           = false
default[:mongodb][:server][:noprealloc]            = false
default[:mongodb][:server][:nssize]                = false
default[:mongodb][:server][:objcheck]              = false
default[:mongodb][:server][:password]              = ""
default[:mongodb][:server][:quota]                 = false
default[:mongodb][:server][:username]              = ""
default[:mongodb][:server][:verbose]               = false

### STARTUP
default[:mongodb][:server][:rest]                  = false
default[:mongodb][:server][:syncdelay]             = 60

### MMS
default[:mongodb][:server][:mms]                   = false
default[:mongodb][:server]['mms-interval']         = ""
default[:mongodb][:server]['mms-name']             = ""
default[:mongodb][:server]['mms-token']            = ""

### REPLICATION
default[:mongodb][:server][:autoresync]            = false
default[:mongodb][:server][:master]                = false
default[:mongodb][:server][:master_source]         = ""
default[:mongodb][:server][:opidmem]               = 0
default[:mongodb][:server][:oplogsize]             = 0
default[:mongodb][:server][:replication]           = false
default[:mongodb][:server][:replSet]               = ""
default[:mongodb][:server][:slave]                 = false
default[:mongodb][:server][:slave_only]            = ""
default[:mongodb][:server][:slave_source]          = ""

### SHARDING
default[:mongodb][:server][:shard_server]          = false

### BACKUP
default[:mongodb][:server][:backup][:backupdir]    = "/var/backups/mongodb"
default[:mongodb][:server][:backup][:cleanup]      = "yes"
default[:mongodb][:server][:backup][:compression]  = "bzip2"
default[:mongodb][:server][:backup][:day]          = 6
default[:mongodb][:server][:backup][:host]         = "localhost"
default[:mongodb][:server][:backup][:latest]       = "yes"
default[:mongodb][:server][:backup][:mailaddress]  = false
default[:mongodb][:server][:backup][:mailcontent]  = "stdout"
default[:mongodb][:server][:backup][:maxemailsize] = 4000



##########################################################################
### CONFIG SERVER
default[:mongodb][:config_server][:bind_ip] = bind_ip
default[:mongodb][:config_server][:config]  = "/etc/mongodb-config.conf"
default[:mongodb][:config_server][:datadir] = "/var/db/mongodb-config"
default[:mongodb][:config_server][:logpath] = "/var/log/mongodb-config.log"
default[:mongodb][:config_server][:pidfile] = "/var/run/mongodb-config.pid"
default[:mongodb][:config_server][:port]    = 27019
default[:mongodb][:config_server][:verbose] = false



##########################################################################
### MONGOS - SHARDING ROUTER
default[:mongodb][:mongos][:bind_ip] = bind_ip
default[:mongodb][:mongos][:config]  = "/etc/mongos.conf"
default[:mongodb][:mongos][:logpath] = "/var/log/mongos.log"
default[:mongodb][:mongos][:pidfile] = "/var/run/mongos.pid"
default[:mongodb][:mongos][:port]    = 27017
default[:mongodb][:mongos][:verbose] = false
