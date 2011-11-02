module HealthManager2
  QUEUE_BATCH_SIZE = 40
  class Nudger
    def initialize( config={} )
      @config = config
      @queue = VCAP::PrioritySet.new
      @queue_batch_size = get_param_from_config_or_constant(:queue_batch_size, @config)
    end

    def deque_batch_of_requests
      @queue_batch_size.times do |i|
        break if @queue.empty?
        message = @queue.remove
        NATS.publish('cloudcontrollers.hm.requests', encode_json(message))
      end
    end

    def start_instances instances

      instances.each do |instance, priority|
        message = {
          :droplet => instance.id,
          :op => :START,
          :last_updated => instance.last_updated,
          :version => instance.live_version,
          :indices => instance.missing_indices
        }
        priority ||= 0
        key = message.clone.delete(:last_updated)
        @queue.insert(message, priority, key)
      end

    end

    def stop_instances instances
    end
  end
end
