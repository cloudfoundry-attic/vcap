require 'fiber'
require 'yajl'

require 'vcap/logging'

module VCAP
  module Stager
  end
end

class VCAP::Stager::TaskResult
  ST_SUCCESS = 0
  ST_FAILED  = 1

  attr_reader :task_id, :status, :details

  class << self
    attr_accessor :redis

    def fetch(task_id, redis=nil)
      redis ||= @redis
      key = key_for_id(task_id)
      result = redis.get(key)
      result ? decode(result) : nil
    end

    def fetch_fibered(task_id, timeout=5, redis=nil)
      redis ||= @redis
      f = Fiber.current
      key = key_for_id(task_id)
      logger = VCAP::Logging.logger('vcap.stager.task_result.fetch_fibered')

      logger.debug("Fetching result for key '#{key}' from redis")

      get_def = redis.get(key)
      get_def.timeout(timeout)
      get_def.errback do |e|
        e = VCAP::Stager::TaskResultTimeoutError.new("Timed out fetching result") if e == nil
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
        result ? decode(result) : nil
      else
        raise result
      end
    end

    def decode(enc_res)
      dec_res = Yajl::Parser.parse(enc_res)
      VCAP::Stager::TaskResult.new(dec_res['task_id'], dec_res['status'], dec_res['details'])
    end

    def key_for_id(task_id)
      "staging_task_result:#{task_id}"
    end
  end

  def initialize(task_id, status, details)
    @task_id = task_id
    @status  = status
    @details = details
  end

  def was_success?
    @status == ST_SUCCESS
  end

  def encode
    h = {
      :task_id => @task_id,
      :status  => @status,
      :details => @details,
    }
    Yajl::Encoder.encode(h)
  end

  def save(redis=nil)
    redis ||= self.class.redis
    key = self.class.key_for_id(@task_id)
    val = encode()
    redis.set(key, val)
  end
end
