# Connect to NATS, advertise our presence, and then load subscriptions.
#
# FIXME - We also set the environment variable to ensure
# that any code that might beat this to completion
# will use the right NATS host.
# Remove when we're sure it isn't necessary.
ENV['NATS_URI'] = AppConfig[:mbus]

require 'nats_timed_request'

NATS.on_error do |e|
  if e.kind_of? NATS::ConnectError
    Rails.logger.error("EXITING! NATS connection failed: #{e}")
    # Fail fast
    STDERR.puts("EXITING! NATS connection failed: #{e}")
    exit!
  else
    Rails.logger.error("NATS problem, #{e}")
  end
end

EM.error_handler do |e|
  Rails.logger.error "Eventmachine problem, #{e}"
  Rails.logger.error("#{e.backtrace.join("\n")}")
  # Fail fast
  STDERR.puts "Eventmachine problem, #{e}"
  exit 1
end

EM.next_tick do
  NATS.start(:uri => AppConfig[:mbus]) do
    options = {:type => 'CloudController', :config => AppConfig, :index => AppConfig[:index]}
    options[:host] = CloudController.bind_address
    VCAP::Component.register(options)
    require File.join(File.expand_path('..', __FILE__), 'varz')
    files = Dir.glob(Rails.root.join('app','subscriptions','*.rb'))
    files.each { |fn| require(fn) }
  end
end

