require 'vcap/spec/forked_component/base'

require 'erb'

module VCAP
  module Stager
    module Spec
    end
  end
end

class VCAP::Stager::Spec::ForkedRedisServer < VCAP::Spec::ForkedComponent::Base
  CONF_TEMPLATE = File.expand_path('../../fixtures/redis.conf.erb', __FILE__)

  attr_reader :log_dir, :port

  def initialize(redis_path, port, log_dir='/tmp', keep_logs=false)
    @port       = port
    @log_dir    = log_dir
    @redis_conf = File.join(@log_dir, 'redis.conf')
    @pid_file   = File.join(@log_dir, 'redis.pid')
    write_conf(@redis_conf)

    super("#{redis_path} #{@redis_conf}" , 'redis-server', @log_dir)
  end

  def ready?
    begin
      s = TCPSocket.new('127.0.0.1', @port)
      s.close
      true
    rescue => e
      false
    end
  end

  private

  def write_conf(filename)
    template = ERB.new(File.read(CONF_TEMPLATE))
    # Wish I could pass these to ERB instead of it reaching into the current scope
    # Investigate using something like liquid templates...
    port = @port
    conf = template.result(binding())
    File.open(filename, 'w+') {|f| f.write(conf) }
  end
end
