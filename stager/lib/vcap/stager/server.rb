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
  def initialize(nats_uri, thread_pool, user_manager, config={})
    @nats_uri    = nats_uri
    @nats_conn   = nil
    @sids        = []
    @config      = config
    @task_config = create_task_config(config, user_manager)
    @logger      = VCAP::Logging.logger('vcap.stager.server')
    @thread_pool = thread_pool
    @user_manager = user_manager
    @shutdown_thread = nil
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
      EM.next_tick { EM.stop }
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
      sq = "vcap.stager.#{q}"
      @sids << @nats_conn.subscribe(sq, :queue => sq) do |msg, reply_to|
        add_task(msg)
      end
    end
  end

  def teardown_subscriptions
    @sids.each { |sid| @nats_conn.unsubscribe(sid) }

    @sids = []
  end

  def add_task(task_msg)
    begin
      @logger.debug("Decoding task '#{task_msg}'")

      request = Yajl::Parser.parse(task_msg)
    rescue => e
      @logger.warn("Failed decoding '#{task_msg}': #{e}")
      @logger.warn(e)
      return
    end

    @thread_pool.enqueue { execute_request(request) }

    @logger.info("Enqueued request #{request}")

    nil
  end

  def execute_request(request)
    task = VCAP::Stager::Task.new(request, @task_config)

    result = nil
    begin
      task.perform

      result = VCAP::Stager::TaskResult.new(task.task_id, task.log)

      @logger.info("Task #{task.task_id} succeeded")
    rescue VCAP::Stager::TaskError => te
      @logger.warn("Task #{task.task_id} failed: #{te}")

      result = VCAP::Stager::TaskResult.new(task.task_id, task.log, te)
    rescue Exception => e
      @logger.error("Unexpected exception: #{e}")
      @logger.error(e)

      raise e
    end

    EM.next_tick { @nats_conn.publish(request["notify_subj"], result.encode) }

    nil
  end

  def create_task_config(server_config, user_manager)
    task_config = {
      :ruby_path => server_config[:ruby_path],
      :run_plugin_path => server_config[:run_plugin_path],
      :secure_user_manager => user_manager,
    }

    if server_config[:dirs]
      task_config[:manifest_root] = server_config[:dirs][:manifests]
    end

    task_config
  end
end
