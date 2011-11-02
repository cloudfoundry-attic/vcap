
module HealthManager2
  class Nudger
    def initialize( config={} )
      @config = config
    end

    def publish_ping
      NATS.publish('healthmanager.nats.ping', Time.now.to_f.to_s)
    end

    def start_instances instances
    end

    def stop_instances instances
    end
  end

end
