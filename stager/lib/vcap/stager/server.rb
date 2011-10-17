require 'nats/client'
require 'yajl'

require 'vcap/component'
require 'vcap/json_schema'
require 'vcap/logging'

require 'vcap/stager/ipc'
require 'vcap/stager/task'
require 'vcap/stager/task_manager'

module VCAP
  module Stager
  end
end

class VCAP::Stager::Server
  def initialize(nats_uri, task_mgr, config={})
    @nats_uri  = nats_uri
    @nats_conn = nil
    @task_mgr  = nil
    @sids      = []
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
        setup_subscriptions()
        @task_mgr.varz = VCAP::Component.varz
        @logger.info("Stager active")
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

  def setup_subscriptions
    for qn in @config[:queues]
      @sids << @nats_conn.subscribe(qn, :queue => qn) {|msg| handle_request(msg) }
      @logger.info("Subscribed to #{qn}")
    end
  end

  def teardown_subscriptions
    for sid in @sids
      @nats_conn.unsubscribe(sid)
    end
    @sids = []
  end

  def handle_request(msg)
    @logger.debug("Handling msg #{msg}")
    begin
      req = VCAP::Stager::Ipc::Request.decode(msg)
    rescue VCAP::Stager::Ipc::IpcError => e
      @logger.warn("Error decoding request '#{msg}', #{e}")
      return
    end

    if req.method == :add_task
      resp = VCAP::Stager::Ipc::Response.for_request(req)
      task = VCAP::Stager::Task.new(req.args['app_id'],
                                    req.args['app_properties'],
                                    req.args['download_uri'],
                                    req.args['upload_uri'],
                                    resp)
      @task_mgr.add_task(task)
    else
      @logger.warn("Cannot handle method #{req.method}")
    end
  end
end
