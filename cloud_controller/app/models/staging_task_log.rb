class StagingTaskLog
  class << self
    attr_accessor :redis

    def key_for_id(app_id)
      "staging_task_log:#{app_id}"
    end

    def fetch_fibered(app_id, redis=nil, timeout=5)
      redis ||= @redis
      f = Fiber.current
      key = key_for_id(app_id)
      logger = VCAP::Logging.logger('vcap.stager.task_result.fetch_fibered')

      logger.debug("Fetching result for key '#{key}' from redis")

      get_def = redis.get(key)
      get_def.timeout(timeout)
      get_def.errback do |e|
        e = VCAP::Stager::StagingTimeoutError.new("Timed out fetching result") if e == nil
        logger.error("Failed fetching result for key '#{key}': #{e}")
        logger.error(e)
        f.resume([false, e])
      end
      get_def.callback do |result|
        logger.debug("Fetched result for key '#{key}' => '#{result}'")
        f.resume([true, result])
      end

      was_success, result = Fiber.yield

      if was_success
        result ? StagingTaskLog.new(app_id, result) : nil
      else
        raise result
      end
    end
  end

  attr_reader :app_id, :task_log

  def initialize(app_id, task_log)
    @app_id   = app_id
    @task_log = task_log
  end

  def save(redis=nil)
    redis ||= self.class.redis
    key = self.class.key_for_id(@app_id)
    redis.set(key, @task_log)
  end
end
