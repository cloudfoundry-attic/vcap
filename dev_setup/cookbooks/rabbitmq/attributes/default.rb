include_attribute "deployment"

default[:rabbitmq][:supported_versions] = {
        "2.4" => "2.4.1",
}
default[:rabbitmq][:version_aliases] = {
        "current" => "2.4",
}
default[:rabbitmq][:default_version] = "2.4"

default[:rabbitmq][:path] = File.join(node[:deployment][:home], "deploy", "rabbitmq")
default[:rabbitmq][:id] = {
  "2.4.1" => "eyJzaWciOiJVOUo4bW9Kci9tSlY2VW84WG9sa1NVMEFMb0k9Iiwib2lkIjoi%0ANGU0ZTc4YmNhMTFlMTIxMDA0ZTRlN2Q1MTFmODIxMDUwNWE5N2EwZjI4MDUi%0AfQ==%0A"
}
default[:rabbitmq][:checksum] = {
  "2.4.1" => "1cc8dbe3a54b7ef454adb3b6f3bce2f4c798e45ab1608b9600b2dc01a04e5858"
}

default[:rabbitmq][:erlang_id] = "eyJzaWciOiJIb2RpNmdVdnp0S2VHSGRtRUxYQ3dGWnc3WHM9Iiwib2lkIjoi%0ANGU0ZTc4YmNhMzFlMTIxMDA0ZTRlN2Q1MTQ3NDVmMDUwNTljZDgxMmY5YWMi%0AfQ==%0A"
default[:rabbitmq][:erlang_checksum] = "4c72446596803e8a41ec06e7bee5e840d81756f25613bbe3042609c7d0cb0d6b"

default[:rabbitmq_gateway][:service][:timeout] = "15"
default[:rabbitmq_gateway][:node_timeout] = "10"

default[:rabbitmq_node][:index] = "0"
default[:rabbitmq_node][:token] = "changerabbitmqtoken"
default[:rabbitmq_node][:op_time_limit] = "6"
default[:rabbitmq_node][:rabbitmq_start_timeout] = "5"
default[:rabbitmq_node][:proxy_dir] = File.join(node[:deployment][:home], "deploy", "bandwidth_proxy", "bin")
default[:rabbitmq_node][:proxy_id] = "eyJzaWciOiJpQXZ5aUYyZWVVZmEyU3RXUW82UVIveHZxRWM9Iiwib2lkIjoi%0ANGU0ZTc4YmNhMTFlMTIyMjA0ZTRlOTg2MzhiNzYzMDUwYjcxMzk2YjVmNzIi%0AfQ==%0A"
default[:rabbitmq_node][:proxy_checksum] = "2b17a3b9ab3142efaf731d1e6adbe338cdcc9651667b17af93bbaa3684d605f7"
