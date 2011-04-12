
module CloudController
  class << self

    def setup_updates
      @timestamp = Time.now
      @current_num_requests = 0
      EM.add_periodic_timer(1) { CloudController.update_requests_per_sec }
    end

    def update_requests_per_sec
      # Update our timestamp and calculate delta for reqs/sec
      now = Time.now
      delta = now - @timestamp
      @timestamp = now
      # Now calculate Requests/sec
      new_num_requests = VCAP::Component.varz[:requests]
      VCAP::Component.varz[:requests_per_sec] = ((new_num_requests - @current_num_requests)/delta.to_f).to_i
      @current_num_requests = new_num_requests
    end
  end
end

# Initialize varzs

EM.next_tick do
  VCAP::Component.varz[:requests] = 0
  VCAP::Component.varz[:pending_requests] = 0
  VCAP::Component.varz[:requests_per_sec] = 0
  VCAP::Component.varz[:running_stage_cmds] = 0
  VCAP::Component.varz[:pending_stage_cmds] = 0

  CloudController.setup_updates
end



