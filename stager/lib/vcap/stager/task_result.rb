require 'yajl'

require 'vcap/json_schema'

module VCAP
  module Stager
  end
end

class VCAP::Stager::TaskResult
  SCHEMA = VCAP::JsonSchema.build do
    { :task_id         => String,
      :task_log        => String,
      optional(:error) => String,
    }
  end

  class << self
    def decode(enc_res)
      dec_res = Yajl::Parser.parse(enc_res)
      SCHEMA.validate(dec_res)
      dec_res['error'] = VCAP::Stager::TaskError.decode(dec_res['error']) if dec_res['error']
      VCAP::Stager::TaskResult.new(dec_res['task_id'], dec_res['task_log'], dec_res['error'])
    end
  end

  attr_reader :task_id, :task_log, :error

  def initialize(task_id, task_log, error=nil)
    @task_id  = task_id
    @task_log = task_log
    @error    = error
  end

  def encode
    h = {
      :task_id  => @task_id,
      :task_log => @task_log,
    }
    h[:error] = @error.encode if @error

    Yajl::Encoder.encode(h)
  end

  def was_success?
    @error == nil
  end
end
