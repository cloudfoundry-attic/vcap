require File.join(File.dirname(__FILE__), '..','spec_helper')

VCAP::Logging.setup_from_config({'level' => ENV['LOG_LEVEL'] || 'warn'})

module HealthManager2
  def in_em(timeout=2)
    EM.run do
      EM.add_timer(timeout) do
        EM.stop
      end
      yield
    end
  end
  class Manager
    def self.set_now(t)
      @now = t
    end
  end
  def set_now(t) #for testing
    Manager.set_now(t)
  end
  def make_heartbeat(apps)
    hb = []
    apps.each do |app|
      app.num_instances.times {|index|
        hb << {
          'droplet' => app.id,
          'version' => app.live_version,
          'instance' => "#{app.live_version}-#{index}",
          'index' => index,
          'state' => STARTED,
          'state_timestamp' => now
        }
      }
    end
    {'droplets' => hb, 'dea'=>'123456789abcdefgh'}
  end
end
