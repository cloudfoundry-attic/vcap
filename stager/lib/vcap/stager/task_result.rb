require 'yajl'

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
