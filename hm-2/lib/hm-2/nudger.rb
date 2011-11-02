module HealthManager2
  QUEUE_BATCH_SIZE = 40
  class Nudger
    def initialize( config={} )
      @config = config
      @queue = VCAP::PrioritySet.new
      @queue_batch_size = get_param_from_config_or_constant(:queue_batch_size, @config)
      @logger = get_logger
    end

    def deque_batch_of_requests
      @queue_batch_size.times do |i|
        break if @queue.empty?
        message = @queue.remove
        @logger.info("nudger: NATS.publish: cloudcontrollers.hm.requests: #{message}")
        unless ENV['HM-2_SHADOW']=='false'
          NATS.publish('cloudcontrollers.hm.requests', encode_json(message))
        end
      end
    end

    def start_instances(instances)
      @logger.debug { "nudger: starting instances: #{instances}" }
      instances.each do |app, priority|
        message = {
          :droplet => app.id,
          :op => :START,
          :last_updated => app.last_updated,
          :version => app.live_version,
          :indices => app.missing_indices
        }
        queue(message, priority)
      end
    end

    def stop_instance(app, instance, priority)
      @logger.debug { "nudger: stopping instances: app: #{app} instance: #{instance}" }
      message = {
        :droplet => app.id,
        :op => :STOP,
        :last_updated => app.last_updated,
        :instances => instance
      }
      queue(message,priority)
    end
  end

  private

  def queue(message, priority)
    priority ||= NORMAL_PRIORITY
    key = message.clone.delete(:last_updated)
    @queue.insert(message, priority, key)
  end
end
