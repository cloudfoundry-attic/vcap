require 'nats/client'
require 'resque'

require 'vcap/stager/task'
require 'vcap/stager/task_result'

class StagingTaskManager
  DEFAULT_TASK_TIMEOUT = 120

  def initialize(opts={})
    @logger    = opts[:logger]    || VCAP::Logging.logger('vcap.cc.staging_manager')
    @nats_conn = opts[:nats_conn] || NATS.client
    @timeout   = opts[:timeout]   || DEFAULT_TASK_TIMEOUT
  end

  # Enqueues a staging task in redis, blocks until task completes or a timeout occurs.
  # Updates the app based on the result of the staging operation.
  #
  # @param  app     App     The app to be staged
  # @param  dl_uri  String  URI that the stager can download the app from
  # @param  ul_uri  String  URI that the stager should upload the staged droplet to
  #
  # @return VCAP::Stager::TaskResult
  def run_staging_task(app, dl_uri, ul_uri)
    inbox = "cc.staging." + VCAP.secure_uuid
    nonce = VCAP.secure_uuid
    f = Fiber.current

    # Wait for notification from the stager
    exp_timer = nil
    sid = @nats_conn.subscribe(inbox) do |msg|
      @logger.debug("Received result from stager on '#{inbox}' : '#{msg}'")
      @nats_conn.unsubscribe(sid)
      EM.cancel_timer(exp_timer)
      f.resume(msg)
    end

    # Setup timer to expire our request if we don't hear a response from the stager in time
    exp_timer = EM.add_timer(@timeout) do
      @logger.warn("Staging timed out for app_id=#{app.id} (timeout=#{@timeout}, unsubscribing from '#{inbox}'",
                   :tags => [:staging])
      @nats_conn.unsubscribe(sid)
      f.resume(nil)
    end

    Resque.enqueue(VCAP::Stager::Task, app.id, app.staging_task_properties, dl_uri, ul_uri, inbox)
    @logger.debug("Enqeued staging task to redis for app_id=#{app.id}, ", :tags => [:staging])

    begin
      result = Fiber.yield
      if !result
        result = VCAP::Stager::TaskResult.new(app.id,
                                              VCAP::Stager::TaskResult::ST_FAILED,
                                              "Timed out waiting for reply from stager")
      else
        result = VCAP::Stager::TaskResult.decode(result)
      end
    rescue => e
      @logger.error("Error updated staging information for app_id=#{app.id}", :tags => [:staging])
      @logger.error(e, :tags => [:staging])
      raise e
    end

    result
  end
end
