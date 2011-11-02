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
    CloudController.logger.error("EXITING! NATS connection failed: #{e}")
    CloudController.logger.error(e)

    # Fail fast
    STDERR.puts("EXITING! NATS connection failed: #{e}")
    exit!
  else
    CloudController.logger.error("NATS problem, #{e}")
    CloudController.logger.error(e)
  end
end

EM.error_handler do |e|
  CloudController.logger.error "Eventmachine problem, #{e}"
  CloudController.logger.error(e)
  # Fail fast
  STDERR.puts "Eventmachine problem, #{e}"
  exit 1
end

EM.next_tick do
  NATS.start(:uri => AppConfig[:mbus]) do
    status_config = AppConfig[:status] || {}
    VCAP::Component.register(:type => 'CloudController',
                             :host => CloudController.bind_address,
                             :index => AppConfig[:index],
                             :config => AppConfig,
                             :port => status_config[:port],
                             :user => status_config[:user],
                             :password => status_config[:password])

    require File.join(File.expand_path('..', __FILE__), 'varz')
    files = Dir.glob(Rails.root.join('app','subscriptions','*.rb'))
    files.each { |fn| require(fn) }
  end
end

