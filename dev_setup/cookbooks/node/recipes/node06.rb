node_version = node[:node06][:version]
node_source_id = node[:node06][:id]
node_path = node[:node06][:path]

cf_node_install(node_version, node_source_id, node_path)
