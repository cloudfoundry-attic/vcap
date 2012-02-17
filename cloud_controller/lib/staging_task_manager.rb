require 'nats/client'

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
  #
  # @param  app     App     The app to be staged
  # @param  dl_uri  String  URI that the stager can download the app from
  # @param  ul_uri  String  URI that the stager should upload the staged droplet to
  #
  # @return VCAP::Stager::TaskResult
  def run_staging_task(app, dl_uri, ul_uri)
    inbox = "cc.staging." + VCAP.secure_uuid
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

    task = VCAP::Stager::Task.new(app.id, app.staging_task_properties, dl_uri, ul_uri, inbox)
    task.enqueue('staging')
    @logger.debug("Enqeued staging task for app_id=#{app.id}.", :tags => [:staging])

    reply = Fiber.yield
    if reply
      result = VCAP::Stager::TaskResult.decode(reply)
      StagingTaskLog.new(app.id, result.task_log).save
    else
      result = VCAP::Stager::TaskResult.new(nil, nil, "Timed out waiting for stager's reply.")
    end

    result
  end
end
