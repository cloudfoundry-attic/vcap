#this is a thin wrapper over VCAP::Component varz/healthz functionality.
#perhaps this should be eventually migrated to common/component.

module HM2
  class Varz
    def initialize(config = {})
      @config = config
      @counters = {}
    end

    def setup_varz

      declare_counter :total_apps
      declare_counter :total_users
      declare_counter :total_instances

      declare_counter :running_instances #nats/harmonizer
      declare_counter :crashed_instances #inc
      declare_counter :down_instances

      declare_counter :queue_length

      declare_node :running
      declare_node :running, :frameworks
      declare_node :running, :runtimes

      declare_node :users #just use get/set to populate

      declare_node :total
      declare_node :total, :frameworks
      declare_node :total, :runtimes

      #TODO: under these, the frameworks and runtimes are entered dynamically

      declare_counter :heartbeat_msgs_received #nats-based
      declare_counter :droplet_exited_msgs_received #nats-based
      declare_counter :droplet_updated_msgs_received
      declare_counter :healthmanager_status_msgs_received
      declare_counter :healthmanager_health_request_msgs_received

    end

    def declare_node(*path)
      check_var_exists(*path[0...-1])
      h,k = get_last_hash_and_key(*path)
      h[k] = {}
    end

    def declare_counter(*path)
      check_var_exists(*path[0...-1])

      h,k = get_last_hash_and_key(*path)
      raise ArgumentError.new("Counter #{path} already declared") if h[k]
      h[k] = 0
    end

    def reset(*path)
      check_var_exists(*path)
      h,k = get_last_hash_and_key(*path)
      h[k] = 0
    end

    def inc(*path)
      check_var_exists(*path)
      h,k= get_last_hash_and_key(*path)
      h[k] += 1
    end

    def get(*path)
      check_var_exists(*path)
      h,k = get_last_hash_and_key(*path)
      h[k]
    end

    def set(value, *path)
      check_var_exists(*path)
      h,k = get_last_hash_and_key(*path)
      h[k] = value
    end

    def get_varz
      @counters
    end

    private
    def get_last_hash_and_key(*path)

      counter = @counters
      path[0...-1].each { |p| counter = counter[p] }
      return counter, path.last
    end

    def check_var_exists(*path)
      c = @counters
      path.each { |var|
        raise ArgumentError.new("undeclared: #{var} in #{path}") unless c[var]
        c = c[var]
      }
    end
  end

end
