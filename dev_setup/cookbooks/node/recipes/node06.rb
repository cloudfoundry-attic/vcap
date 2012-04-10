node_version = node[:node06][:version]
node_source = node[:node06][:source]
node_path = node[:node06][:path]

cf_node_install(node_version, node_source, node_path)
