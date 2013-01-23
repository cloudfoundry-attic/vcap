include_attribute "backup"
include_attribute "service_lifecycle"

default[:postgresql][:supported_versions] = {
        "9.0" => "9.0",
}
default[:postgresql][:version_aliases] = {
        "current" => "9.0",
}
default[:postgresql][:default_version] = "9.0"

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

default[:postgresql][:id][:server] = {
        "8.4" => {
                "x86_64" => 'eyJzaWciOiIrRCtLdGV2dlBpc3A5ZmR1RlpEZ2R5dmQvWWs9Iiwib2lkIjoi%0ANGU0ZTc4YmNhNTFlMTIyMjA0ZTRlOTg2M2YyOGYzMDUwMmU4NjcyYTExN2Ei%0AfQ==%0A',
                "i686"   => 'eyJzaWciOiJBbEhQODh0aU1TMHYxUWlNcDVTTDdoSldpVlk9Iiwib2lkIjoi%0ANGU0ZTc4YmNhMjFlMTIyMjA0ZTRlOTg2MzkyNmIxMDUwMmU4NzMxN2E2OTAi%0AfQ==%0A'
        },
        "9.0" => {
                "x86_64" => 'eyJzaWciOiI4R2xRVEQ3ZWNzY2VDK0FtS1NKYTN3RXR3aFk9Iiwib2lkIjoi%0ANGU0ZTc4YmNhMjFlMTIxMjA0ZTRlODZlZTE1MWJjMDUwMmU4NjhkNDYwMjUi%0AfQ==%0A',
                "i686"   => 'eyJzaWciOiJjRGl6SXhPMXpKNXUwb1Vva0NqYnV1ZTQvYzA9Iiwib2lkIjoi%0ANGU0ZTc4YmNhMTFlMTIxMjA0ZTRlODZlZTE1Mjk0MDUwMmU4NzNiZWZkZTYi%0AfQ==%0A'
        }
}

default[:postgresql][:checksum][:server] = {
        "8.4" => {
                "x86_64" => '2fbcdb3e2916524edbf9d53709ecad757c99ab2a160d6a7f07faa897e834f3d9',
                "i686"   => '1fb349481d3995ad51290e7f8e2802253c08f0977258d8c67c7a2cc45ea5846f'
        },
        "9.0" => {
                "x86_64" => '4898a37e2a5c6c4bc8c7f36b427dd027011e6d44f3539dfa1aca1f1601294349',
                "i686"   => 'd8b43aa2583b527a204224b6703b06fe9ba332d07272f54c2ccea1062b9c4617'
        }
}

default[:postgresql][:id][:server_common] = 'eyJzaWciOiJGcEZic2RGakRSdW1CaXE4N1NmcDJtSmh5OTQ9Iiwib2lkIjoi%0ANGU0ZTc4YmNhMjFlMTIxMDA0ZTRlN2Q1MTFmNTUzMDUwMmU4NGZiZWNmNTki%0AfQ==%0A'
default[:postgresql][:checksum][:server_common] = 'cf57380ccecb7bfcdbd1652094011370f6448935743ddf4027776801eefaeefb'

default[:postgresql][:id][:client] = {
        "8.4" => {
                "x86_64" => 'eyJzaWciOiJlVXFGUytGZGZCdDJzWHBGWDJFL1oyOXdZSlE9Iiwib2lkIjoi%0ANGU0ZTc4YmNhNjFlMTIyMjA0ZTRlOTg2NDNkOWFlMDUwMmU4NWNkNzZhNGYi%0AfQ==%0A',
                "i686"   => 'eyJzaWciOiJzZmZDd3lwUEY5aDBhbC9UcVpYUVdjZys5bVk9Iiwib2lkIjoi%0ANGU0ZTc4YmNhNjFlMTIyMDA0ZTRlOGVjNmI0NGI2MDUwMmU4ODM5ODY4YmQi%0AfQ==%0A'
        },
        "9.0" => {
                "x86_64" => 'eyJzaWciOiJGT2h4YW9wcE5YdmRNQjdTSlRlVzJWR0xmRUk9Iiwib2lkIjoi%0ANGU0ZTc4YmNhMTFlMTIxMjA0ZTRlODZlZTE1Mjk0MDUwMmU4NWQ3MjFiOGYi%0AfQ==%0A',
                "i686"   => 'eyJzaWciOiJnVEhuZFV1R0M3VERiTzJGcEE4MTgzckFPMEU9Iiwib2lkIjoi%0ANGU0ZTc4YmNhMTFlMTIxMDA0ZTRlN2Q1MTFmODIxMDUwMmU4ODQzMjQ1NTQi%0AfQ==%0A'
        }
}

default[:postgresql][:checksum][:client] = {
        "8.4" => {
                "x86_64" => '4aef4c70aa9e429b5db517104fb79aa7098765af91847f22cbfd503bb8b96fa5',
                "i686"   => 'ab4825d4d21f6bd2b40376cd77f45b076202947d6e9646809b9495233b7363a0'
        },
        "9.0" => {
                "x86_64" => 'a8e78d95b1cc7308153c95aaeff174d54bdce6f44ec98f5ddc92afbc1c919e31',
                "i686"   => '5d2275621e833f0290259aec1a032493640281db85978b181c08d85a0bf402e0'
        }
}

default[:postgresql][:id][:client_common] = 'eyJzaWciOiJET0JEQmpUbUhmNWt2YU82ZlJMTWRFUElNSFE9Iiwib2lkIjoi%0ANGU0ZTc4YmNhMjFlMTIyMjA0ZTRlOTg2MzkyNmIxMDUwMmU4NTU0YzBmOWIi%0AfQ==%0A'
default[:postgresql][:checksum][:client_common] = 'a2d7a96b8b42ea5d2e39c26a3d13c72f05d8036c96b18399a3dd023b6b99418b'

default[:postgresql][:id][:libpq] = {
        "x86_64" => 'eyJzaWciOiI2Q21GcmhocWpPaTFocEFhMlp2TFpZVlFOMGM9Iiwib2lkIjoi%0ANGU0ZTc4YmNhNTFlMTIyMDA0ZTRlOGVjNjg0MDc3MDUwMmU4NDc0MzFmMDIi%0AfQ==%0A',
        "i686"   => 'eyJzaWciOiJ0elRjblZhODlxaU9JYjFpNmo3eWpjY0RxNTQ9Iiwib2lkIjoi%0ANGU0ZTc4YmNhMTFlMTIyMDA0ZTRlOGVjNjQ4NDMxMDUwMmU4OTQyZjNiYjQi%0AfQ==%0A'
}

default[:postgresql][:checksum][:libpq] = {
        "x86_64" => 'b6a7fe7634c41717757481713b24b0c0d9eeb5937875daea7aba17c7750e3f9e',
        "i686"   => '58943d9d8b657d974271a0022f44d57fb9e2a9863cbf5cd59d84e1f308eef33e'
}

default[:postgresql][:id][:libpq_dev] = {
        "x86_64" => 'eyJzaWciOiJGRTVieFBiRFc0Z0hPSDBra2dMTTRpa1luWW89Iiwib2lkIjoi%0ANGU0ZTc4YmNhNTFlMTIyMjA0ZTRlOTg2M2YyOGYzMDUwMmVmZjVjZDdjNDMi%0AfQ==%0A',
        "i686"   => 'eyJzaWciOiIxV0UwMWx3N01BcWpTUW5CdEdBN0xDVW0yTEk9Iiwib2lkIjoi%0ANGU0ZTc4YmNhNDFlMTIxMjA0ZTRlODZlZTUzOTIxMDUwMmVmZjcyMTEwYWYi%0AfQ==%0A'
}

default[:postgresql][:checksum][:libpq_dev] = {
        "x86_64" => 'f2153bb1dd36f61fbe0d207c3d62462f6880f802919a9699749719beb64412f4',
        "i686"   => 'a3d25b3a43d3454c07cd2fea026b33d8f64007b6902e5d814d315432d3bc0483'
}
