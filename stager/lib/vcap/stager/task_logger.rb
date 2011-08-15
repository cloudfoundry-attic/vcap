require 'vcap/logging'

module VCAP
  module Stager
  end
end

# This creates the user visible staging log. If configured with a vcap logger,
# it will log to both the public log and the vcap log. This helps avoid an
# abundance of code like the following:
#
#   @public_logger.info("Starting staging")
#   @vcap_logger.info("Starting staging")
#
#
class VCAP::Stager::TaskLogger
  attr_reader :public_log

  def initialize(vcap_logger=nil)
    @vcap_logger   = vcap_logger
    @public_log    = ''
    @public_logger = make_public_logger(@public_log)
  end

  def method_missing(method, *args, &blk)
    @public_logger.send(method, *args, &blk)
    @vcap_logger.send(method, *args, &blk) if @vcap_logger
  end

  private

  class PublicLogFormatter < VCAP::Logging::Formatter::BaseFormatter
    def format_record(log_record)
      "[%s] %s\n" % [Time.now.strftime('%F %H:%M:%S'), log_record.data]
    end
  end

  def make_public_logger(buf)
    sink_map = VCAP::Logging::SinkMap.new(VCAP::Logging::LOG_LEVELS)
    str_sink = VCAP::Logging::Sink::StringSink.new(buf, PublicLogFormatter.new)
    sink_map.add_sink(nil, nil, str_sink)
    ret = VCAP::Logging::Logger.new('public_logger', sink_map)
    ret.log_level = :info
    ret
  end

end
