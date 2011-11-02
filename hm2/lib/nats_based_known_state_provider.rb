require 'health_manager2'

module HealthManager2

  #this implementation maintains the known state by listening to the
  #DEA heartbeat messages
  class NatsBasedKnownStateProvider < KnownStateProvider
    def initialize(config={})
      @config = config
      @dea_timeouts = {}
      @apps_in_dea = {}
      super
    end

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

      @logger.debug "process_heartbeat: #{message}"

      message = parse_json(message)
      dea_uuid = message['dea']
      reset_dea_timeout(dea_uuid)

      apps = @apps_in_dea[dea_uuid] = Hash.new

      message['droplets'].each do |beat|
        id = beat['droplet']

        apps[id] ||= Hash.new
        apps[id][:latest_heartbeats] ||= Array.new
        apps[id][:latest_heartbeats] << beat #TODO: unlimited growth!
        get_droplet(id).process_heartbeat(beat)
      end
    end

    #reset as in re-set
    def reset_dea_timeout(dea_uuid)
      scheduler.cancel(@dea_timeouts[dea_uuid]) if @dea_timeouts[dea_uuid]

      @dea_timeouts[dea_uuid] = scheduler.after_interval :dea_timeout_interval do
        check_missing_heartbeats_for_dea(dea_uuid)
      end
    end

    def check_missing_heartbeats_for_dea(dea_uuid)
      apps = @apps_in_dea.delete(dea_uuid)
      return unless apps
      apps.each do |app_id, app|
        get_droplet(app_id).process_heartbeat_missed(app[:latest_heartbeats])
      end
    end

    private
    def scheduler
      find_hm_component(:scheduler, @config)
    end
  end
end
