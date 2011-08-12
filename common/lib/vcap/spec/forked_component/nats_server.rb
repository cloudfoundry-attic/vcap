require 'nats/client'
require 'uri'

require 'vcap/spec/forked_component/base'

module VCAP
  module Spec
    module ForkedComponent
    end
  end
end

class VCAP::Spec::ForkedComponent::NatsServer < VCAP::Spec::ForkedComponent::Base

  attr_reader :uri, :port, :parsed_uri

  def initialize(pid_filename, port, output_basedir='tmp')
    cmd = "ruby -S bundle exec nats-server -p #{port} -P #{pid_filename} -V -D"
    super(cmd, 'nats', output_basedir, pid_filename)
    @port = port
    @uri  = "nats://127.0.0.1:#{@port}"
    @parsed_uri = URI.parse(@uri)
  end

  def ready?
    running? && NATS.server_running?(@parsed_uri)
  end
end
