require 'nats/client'
require 'yajl'

require 'vcap/component'
require 'vcap/json_schema'
require 'vcap/logging'

require 'vcap/stager/task'
require 'vcap/stager/task_manager'

module VCAP
  module Stager
  end
end

class VCAP::Stager::Server
  class Channel
    def initialize(nats_conn, subject, &blk)
      @nats_conn = nats_conn
      @subject   = subject
      @sid       = nil
      @receiver  = blk
    end

    def open
      @sid = @nats_conn.subscribe(@subject, :queue => @subject) {|msg| @receiver.call(msg) }
    end

    def close
      @nats_conn.unsubscribe(@sid)
    end
  end

  def initialize(nats_uri, task_mgr, config={})
    @nats_uri  = nats_uri
    @nats_conn = nil
    @task_mgr  = nil
    @channels  = []
    @config    = config
    @task_mgr  = task_mgr
    @logger    = VCAP::Logging.logger('vcap.stager.server')
  end

  def run
    install_error_handlers()
    install_signal_handlers()
    EM.run do
      @nats_conn = NATS.connect(:uri => @nats_uri) do
        VCAP::Stager::Task.set_defaults(:nats => @nats_conn)
        VCAP::Component.register(:type   => 'Stager',
                                 :index  => @config[:index],
                                 :host   => VCAP.local_ip(@config[:local_route]),
                                 :config => @config,
                                 :nats   => @nats_conn)
        setup_channels()
        @logger.info("Server running")
      end
    end
  end

  # Stops receiving new tasks, waits for existing tasks to finish, then stops.
  def shutdown
    @logger.info("Shutdown initiated, waiting for remaining #{@task_mgr.num_tasks} task(s) to finish")
    @channels.each {|c| c.close }
    @task_mgr.on_idle do
      @logger.info("All tasks completed. Exiting!")
      EM.stop
    end
  end

  private

  def install_error_handlers
    EM.error_handler do |e|
      @logger.error("EventMachine error: #{e}")
      @logger.error(e)
      raise e
    end

    NATS.on_error do |e|
      @logger.error("NATS error: #{e}")
      @logger.error(e)
      raise e
    end
  end

  def install_signal_handlers
    trap('USR2') { shutdown() }
    trap('INT')  { shutdown() }
  end

  def setup_channels
    for qn in @config[:queues]
      channel = Channel.new(@nats_conn, "vcap.stager.#{qn}") {|msg| add_task(msg) }
      channel.open
      @channels << channel
    end
  end

  def add_task(task_msg)
    begin
      @logger.debug("Decoding task '#{task_msg}'")
      task = VCAP::Stager::Task.decode(task_msg)
    rescue => e
      @logger.warn("Failed decoding '#{task_msg}': #{e}")
      @logger.warn(e)
      return
    end
    @task_mgr.add_task(task)
  end
end
