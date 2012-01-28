require 'eventmachine'
require 'service'

if AppConfig[:expire_services]
  expiry_period = AppConfig[:service_expiry_period]
  expiry_delay  = AppConfig[:service_expiry_delay]

  EM.next_tick do
    CloudController.logger.info("Service expiry will begin in #{expiry_delay} seconds")

    EM.add_timer(expiry_delay) do
      Service.expire_services(expiry_period)

      EM.add_periodic_timer(expiry_period) do
        Service.expire_services(expiry_period)
      end
    end
  end
else
  CloudController.logger.info("Not expiring services")
end
