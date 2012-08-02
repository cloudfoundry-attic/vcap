include_attribute "deployment"
include_attribute "backup"
include_attribute "service_lifecycle"
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
        "2.0" => "--nojournal"
}

default[:mongodb][:default_version] = "1.8"

default[:mongodb][:id] = {
        "1.8.5" => {
                "x86_64" => 'eyJzaWciOiJ0NHk5ZzBhRFkxSFZmaGhyNmQ5a0FQZFMxS1U9Iiwib2lkIjoi%0ANGU0ZTc4YmNhNTFlMTIxMjA0ZTRlODZlZThlMmM5MDUwMWEwZTYwOGI4YTMi%0AfQ==%0A',
                "i686"   => 'eyJzaWciOiJ3cHY2Sk5BelhmTUVDYUhWUE1UM2RMYm1tRkk9Iiwib2lkIjoi%0ANGU0ZTc4YmNhMzFlMTIyMjA0ZTRlOTg2M2IxYjc0MDUwMWEwZTZjMDVkNjgi%0AfQ==%0A'
        },
        "2.0.6" => {
                "x86_64" => 'eyJzaWciOiJNTDBqWkJ6NjJ2cWNYWmVaZ3dsUENRWlhjbFE9Iiwib2lkIjoi%0ANGU0ZTc4YmNhNDFlMTIxMjA0ZTRlODZlZTUzOTIxMDUwMWEwZTg2M2IzNTgi%0AfQ==%0A',
                "i686"   => 'eyJzaWciOiJnZUZ5dkNQanNndTc0WUZIUkxUYU80UjhkajA9Iiwib2lkIjoi%0ANGU0ZTc4YmNhMjFlMTIyMjA0ZTRlOTg2MzkyNmIxMDUwMWEwZTk1M2M4MmEi%0AfQ==%0A'
        }
}
default[:mongodb][:checksum] = {
        "1.8.5" => {
                "x86_64" => '0a84e0c749604cc5d523a8d8040beb0633ef8413ecd9e85b10190a30c568bb37',
                "i686"   => '24c6c7706ae2925b1a1b73241ca5a1de0812d32bc7927c939dbeebb045b929e5'
        },
        "2.0.6" => {
                "x86_64" => '26c09e81a67b15eb66260257665d801c55337a97a5fd028a474f5c194a986f18',
                "i686"   => '72278c7fde672d5bd67700fd9dae5893c3e2d7b9ef9a700b0dcc32cb1abd8dc4'
        }
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
