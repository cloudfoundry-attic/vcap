# Copyright (c) 2009-2011 VMware, Inc.
#

DEFAULT_CLOUD_FOUNDRY_EXCLUDED_COMPONENT = 'neo4j|memcached|couchdb|service_broker|elasticsearch|backup_manager|vcap_redis|worker|snapshot_manager|serialization_data_server|echo'

def is_excluded?(name)
  excluded = ENV['CLOUD_FOUNDRY_EXCLUDED_COMPONENT'] || DEFAULT_CLOUD_FOUNDRY_EXCLUDED_COMPONENT
  name.match(excluded) if !excluded.empty?
end


