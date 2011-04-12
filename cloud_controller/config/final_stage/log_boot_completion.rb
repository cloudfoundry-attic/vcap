EM.next_tick do
  CloudController.events.sys_event "Starting VCAP CloudController (#{CloudController.version})"
  CloudController.events.sys_event "Socket Limit:#{EM.set_descriptor_table_size}"
end
