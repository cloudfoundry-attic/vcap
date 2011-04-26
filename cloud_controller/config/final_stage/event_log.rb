require 'pp'
module CloudController
  class Events

    attr_reader :logger

    def initialize
      log_file = AppConfig[:log_file]
      @logger = VCAP.create_logger('cc_events', :log_file => log_file, :log_rotation_interval => AppConfig[:log_rotation_interval])
      @logger.level = 'INFO'
    end

    def sys_event(*args)
      args.unshift(:SYSTEM)
      event(*args)
    end

    def user_event(*args)
      args.unshift(:USER)
      event(*args)
    end

    def event(*args)
      args.unshift(Time.now)
      ev = args.compact.pretty_print_inspect
      logger.info(ev)
      NATS.publish('vcap.cc.events', ev)
    end
  end
end

CloudController.events = CloudController::Events.new

