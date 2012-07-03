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

default[:mongodb][:default_version] = "1.8"
default[:mongodb][:download_base_path_prefix] = "http://fastdl.mongodb.org/linux/mongodb-linux-#{node[:kernel][:machine]}"

default[:mongodb][:id] = {
        "1.8.5" => {
                "x86_64" => 'eyJzaWciOiIzNG9GazhkWFRNZCtZOXVCK0xlMWt0b2VDNVU9Iiwib2lkIjoi%0ANGU0ZTc4YmNhNTFlMTIxMjA0ZTRlODZlZThlMmM5MDRmYzdmMjY3Nzc1ZWIi%0AfQ==%0A',
                "i686"   => 'eyJzaWciOiIzaEZub2dWYi9ad0Y5MVVQSU0rV0hKcUVrZzA9Iiwib2lkIjoi%0ANGU0ZTc4YmNhNTFlMTIxMDA0ZTRlN2Q1MTkwNmNkMDRmYzdmMWY3OGQ4MTAi%0AfQ==%0A'
        },
        "2.0.6" => {
                "x86_64" => 'eyJzaWciOiJXcFFIdzhINXlWcHd5aitZMUNDQ0JJMUZheHM9Iiwib2lkIjoi%0ANGU0ZTc4YmNhNjFlMTIxMjA0ZTRlODZlZWJlNTkxMDRmZjIzMzA1NTUxMmEi%0AfQ==%0A',
                "i686"   => 'eyJzaWciOiJ4aXJ5STRaeDdreXozdDcrRVZjYUZWOWpoeXc9Iiwib2lkIjoi%0ANGU0ZTc4YmNhMjFlMTIyMDA0ZTRlOGVjNjQ3YTU0MDRmZjIzMzI0NDAzOTMi%0AfQ==%0A'
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

default[:mongodb_node][:capacity] = "50"
default[:mongodb_node][:index] = "0"
default[:mongodb_node][:max_memory] = "128"
default[:mongodb_node][:token] = "changemongodbtoken"

default[:mongodb_backup][:config_file] = "mongodb_backup.yml"
default[:mongodb_backup][:cron_time] = "0 5 * * *"
default[:mongodb_backup][:cron_file] = "mongodb_backup.cron"

default[:mongodb_worker][:config_file] = "mongodb_worker.yml"
