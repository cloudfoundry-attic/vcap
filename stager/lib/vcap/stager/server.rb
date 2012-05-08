require 'nats/client'
require 'yajl'

require 'vcap/component'
require 'vcap/json_schema'
require 'vcap/logging'

require 'vcap/stager/task'

module VCAP
  module Stager
  end
end

class VCAP::Stager::Server
  def initialize(nats_uri, thread_pool, plugin_runner_factory, config={})
    @nats_uri    = nats_uri
    @nats_conn   = nil
    @sids        = []
    @config      = config
    @logger      = VCAP::Logging.logger('vcap.stager.server')
    @thread_pool = thread_pool
    @shutdown_thread = nil
    @plugin_runner_factory = plugin_runner_factory
  end

  def run
    install_error_handlers

    install_signal_handlers

    @thread_pool.start

    EM.run do
      @nats_conn = NATS.connect(:uri => @nats_uri) do
        VCAP::Component.register(:type   => 'Stager',
                                 :index  => @config[:index],
                                 :host   => VCAP.local_ip(@config[:local_route]),
                                 :config => @config,
                                 :nats   => @nats_conn)

        setup_subscriptions

        @logger.info("Server running")
      end
    end
  end

  # Stops receiving new tasks, waits for existing tasks to finish, then stops.
  #
  # NB: This is called from a signal handler, so be sure to wrap all EM
  #     interaction with EM.next_tick.
  def shutdown
    num_tasks = @thread_pool.num_active_tasks + @thread_pool.num_queued_tasks
    @logger.info("Shutdown initiated.")
    @logger.info("Waiting for remaining #{num_tasks} task(s) to finish.")

    EM.next_tick { teardown_subscriptions }

    @shutdown_thread = Thread.new do
      # Blocks until all threads have finished
      @thread_pool.shutdown
      EM.next_tick do
        EM.stop
        @logger.info("Shutdown complete")
      end
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
    trap('USR2') { shutdown }
    trap('INT')  { shutdown }
  end

  def setup_subscriptions
    @config[:queues].each do |q|
      @sids << @nats_conn.subscribe(q, :queue => q) do |msg, reply_to|
        @thread_pool.enqueue { execute_request(msg, reply_to) }

        @logger.info("Enqueued request #{msg}")
      end

      @logger.info("Subscribed to #{q}")
    end
  end

  def teardown_subscriptions
    @sids.each { |sid| @nats_conn.unsubscribe(sid) }

    @sids = []
  end

  def execute_request(encoded_request, reply_to)
    begin
      @logger.debug("Decoding request '#{encoded_request}'")

      request = Yajl::Parser.parse(encoded_request)
    rescue => e
      @logger.warn("Failed decoding '#{encoded_request}': #{e}")
      @logger.warn(e)
      return
    end

    task = VCAP::Stager::Task.new(request, @plugin_runner_factory.call)

    result = nil
    begin
      task.perform

      result = {
        "task_id"  => task.task_id,
        "task_log" => task.log,
      }

      @logger.info("Task #{task.task_id} succeeded")
    rescue VCAP::Stager::TaskError => te
      @logger.warn("Task #{task.task_id} failed: #{te}")

      result = {
        "task_id"  => task.task_id,
        "task_log" => task.log,
        "error"    => te.to_s,
      }
    rescue Exception => e
      @logger.error("Unexpected exception: #{e}")
      @logger.error(e)

      raise e
    end

    encoded_result = Yajl::Encoder.encode(result)

    EM.next_tick { @nats_conn.publish(reply_to, encoded_result) }

    nil
  end
end
