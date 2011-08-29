require 'vcap/common'
require 'vcap/spec/forked_component/base'

require 'erb'

module VCAP
  module Stager
    module Spec
    end
  end
end


class VCAP::Stager::Spec::ForkedStager < VCAP::Spec::ForkedComponent::Base
  CONF_TEMPLATE = File.expand_path('../../fixtures/stager_config.yml.erb', __FILE__)
  STAGER_PATH   = File.expand_path('../../../bin/stager', __FILE__)

  attr_reader :log_dir, :nats_port, :manifest_dir, :pid_filename

  def initialize(nats_port, manifest_dir, log_dir='/tmp', keep_logs=false)
    @nats_port    = nats_port
    @manifest_dir = manifest_dir
    @log_dir      = log_dir
    @conf_path    = File.join(@log_dir, 'stager.conf')
    @pid_filename = File.join(@log_dir, 'stager.pid')
    write_conf(@conf_path)

    super("#{STAGER_PATH} -c #{@conf_path} -s 1", 'stager', @log_dir)
  end

  def stop
    return unless @pid && VCAP.process_running?(@pid)
    Process.kill('KILL', @pid)
    Process.waitpid(@pid, 0)
    @pid = nil

    self
  end

  private

  def write_conf(filename)
    template = ERB.new(File.read(CONF_TEMPLATE))
    # Wish I could pass these to ERB instead of it reaching into the current scope
    # Investigate using something like liquid templates...
    nats_port    = @nats_port
    manifest_dir = @manifest_dir
    pid_filename = @pid_filename
    conf = template.result(binding())
    File.open(filename, 'w+') {|f| f.write(conf) }
  end
end
