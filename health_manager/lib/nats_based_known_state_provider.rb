require 'app_state_provider.rb'

module HealthManager2
#this implementation maintains the known state by listening to the
  #DEA heartbeat messages
  class NatsBasedKnownStateProvider < KnownStateProvider

    def start
      NATS.subscribe('dea.heartbeat') do |message|
        process_heartbeat(message)
      end

      NATS.subscribe('droplet.exited') do |message|
        process_droplet_exited(message)
      end
      super
    end

    def process_droplet_exited(message)
      message = parse_json(message)
      id = message['droplet']
      droplet = get_droplet(message['droplet'])

      case message['reason']
      when CRASHED
        droplet.process_exit_crash(message)
      when DEA_SHUTDOWN, DEA_EVACUATION
        droplet.process_exit_dea(message)
      when STOPPED
        droplet.process_exit_stopped(message)
      end
    end

    def process_heartbeat(message)
      message = parse_json(message)
      message['droplets'].each do |beat|
        get_droplet(beat['droplet']).process_heartbeat(beat)
      end
    end
  end

  def parse_json json
    #TODO: use Yajl?
    JSON.parse(json)
  end
end
