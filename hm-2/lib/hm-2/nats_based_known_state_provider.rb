
module HM2

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

      @logger.info("subscribing to heartbeats")
      NATS.subscribe('dea.heartbeat') do |message|
        process_heartbeat(message)
      end

      @logger.info("subscribing to droplet.exited")
      NATS.subscribe('droplet.exited') do |message|
        process_droplet_exited(message)
      end

      @logger.info("subscribing to droplet.updated")
      NATS.subscribe('droplet.updated') do |message|
        process_droplet_updated(message)
      end

      super
    end

    def process_droplet_exited(message)
      @logger.debug {"process_droplet_exited: #{message}"}
      varz.inc(:droplet_exited_msgs_received)
      message = parse_json(message)
      droplet = get_droplet(message['droplet'])

      case message['reason']
      when CRASHED
        varz.inc(:crashed_instances)
        droplet.process_exit_crash(message)
      when DEA_SHUTDOWN, DEA_EVACUATION
        droplet.process_exit_dea(message)
      when STOPPED
        droplet.process_exit_stopped(message)
      end
    end

    def process_heartbeat(message)
      @logger.debug {"known: #process_heartbeat: #{message}"}
      varz.inc(:heartbeat_msgs_received)

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

    def process_droplet_updated(message)
      @logger.debug {"known: #process_droplet_updated: #{message}" }
      varz.inc(:droplet_updated_msgs_received)
      message = parse_json(message)
      get_droplet(message['droplet']).process_droplet_updated(message)
    end

    #reset as in re-set
    def reset_dea_timeout(dea_uuid)
      @logger.debug { "known: dea_timer: reset: #{dea_uuid}" }
      scheduler.cancel(@dea_timeouts[dea_uuid]) if @dea_timeouts[dea_uuid]
      schedule_dea_timeout(dea_uuid)
    end

    def schedule_dea_timeout(dea_uuid)
      @logger.debug { "known: dea_timer: schedule: #{dea_uuid}" }
      @dea_timeouts[dea_uuid] = scheduler.after_interval :dea_timeout_interval do
        @logger.debug { "known: dea_timer: timeout: #{dea_uuid}" }
        check_missing_heartbeats_for_dea(dea_uuid)
        schedule_dea_timeout(dea_uuid)
      end
    end
    def check_missing_heartbeats_for_dea(dea_uuid)
      apps = @apps_in_dea.delete(dea_uuid)
      return unless apps
      apps.each do |app_id, app|
        get_droplet(app_id).process_heartbeat_missed(app[:latest_heartbeats])
      end
    end
  end
end
