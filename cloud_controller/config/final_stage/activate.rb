dir = Pathname.new(File.expand_path('..', __FILE__))

require dir.join('check_staging')
require dir.join('descriptor_table_size')
require dir.join('event_log')
require dir.join('check_database')
require dir.join('bootstrap_users')
require dir.join('message_bus')
require dir.join('redis')
require dir.join('log_boot_completion')

