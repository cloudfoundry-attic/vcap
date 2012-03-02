node_version = node[:node04][:version]
node_source = node[:node04][:source]
node_path = node[:node04][:path]
node_npm = node[:node04][:npm]

cf_node_install(node_version, node_source, node_path, node_npm)
