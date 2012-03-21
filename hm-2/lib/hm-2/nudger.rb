module HM2
  QUEUE_BATCH_SIZE = 40
  class Nudger
    include HM2::Common
    def initialize( config={} )
      @config = config
      @queue = VCAP::PrioritySet.new
      @queue_batch_size = get_param_from_config_or_constant(:queue_batch_size, @config)
      @logger = get_logger
    end

    def deque_batch_of_requests
      @queue_batch_size.times do |i|
        break if @queue.empty?
        message = encode_json(@queue.remove)

        @logger.info("nudger: NATS.publish: cloudcontrollers.hm.requests: #{message}")
        if ENV[HM_SHADOW]=='false'
          NATS.publish('cloudcontrollers.hm.requests', message)
        else
          #do some shadow accounting!
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
      @logger.debug { "nudger: stopping instances: app: #{app.id} instance: #{instance}" }
      message = {
        :droplet => app.id,
        :op => :STOP,
        :last_updated => app.last_updated,
        :instances => instance
      }
      queue(message,priority)
    end

    private
    def queue(message, priority)
      @logger.debug { "nudger: queueing: #{message}, #{priority}" }
      priority ||= NORMAL_PRIORITY
      key = message.clone.delete(:last_updated)
      @queue.insert(message, priority, key)
    end
  end

  class Shadower
    include HM2::Common
    def initialize(config = {})
      @received = {}
      @logger = get_logger
    end

    def subscribe

      subscribe_on('healthmanager.start')
      subscribe_on('cloudcontrollers.hm.requests')

      NATS.subscribe('healthmanager.status') do |message, reply|
        subscribe_on(reply, 'healthmanager.status.reply')
      end

      NATS.subscribe('healthmanager.health') do |message, reply|
        subscribe_on(reply, 'healthmanager.health.reply')
      end
    end
    def subscribe_on(subj, topic = nil)
      topic ||= subj

      #"subjet" is NATS subject. "Topic" is the label for the bin.
      #they are the same except for NATS "reply-to" subjects.

      NATS.subscribe(subj) do |message|
        @logger.info{"shadower: received: #{subj}/#{topic}: #{message}"}

        @received[topic] ||= []
        @received[topic] << message
        if @received[topic].size > 1000
          @received[topic] = @received[topic][500..-1]
        end

        NATS.unsubscribe(subj) if subj!=topic #unsubscribe from "reply-to" subjects
      end
    end
  end
end
