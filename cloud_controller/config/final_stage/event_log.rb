require 'pp'

module CloudController
  class Events

    # The event includes a timestamp, so logging anything other than the event is redundant
    LOG_FORMATTER = VCAP::Logging::Formatter::DelimitedFormatter.new do
      data
    end

    attr_reader :logger

    def initialize
      sinks = []
      sink_map = VCAP::Logging::SinkMap.new(VCAP::Logging::LOG_LEVELS)
      if AppConfig[:event_logging]
        if log_file = AppConfig[:event_logging][:file]
          sink = VCAP::Logging::Sink::FileSink.new(log_file, LOG_FORMATTER)
          sink.autoflush = true
          sinks << sink
        end

        if name = AppConfig[:event_logging][:syslog]
          sink = VCAP::Logging::Sink::SyslogSink.new(name, :formatter => LOG_FORMATTER)
          sink.autoflush = true
          sinks << sink
        end
      end

      # Log to stdout if no sinks are specified
      sinks << VCAP::Logging::Sink::StdioSink.new(STDOUT, LOG_FORMATTER) unless sinks.length > 0

      sinks.each {|s| sink_map.add_sink(nil, nil, s) }
      @logger = VCAP::Logging::Logger.new('cc_events', sink_map)
      @logger.log_level = :info
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
      NATS.publish('vcap.cc.events', args.to_json)
    end
  end
end

CloudController.events = CloudController::Events.new

