node_version = node[:node08][:version]
node_source_id = node[:node08][:id]
node_path = node[:node08][:path]

cf_node_install(node_version, node_source_id, node_path)
