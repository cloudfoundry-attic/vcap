#this class describes in a declarative manner the policy that HealthManager2 is implementing.
#it describes a set of rules that recognize certain conditions (e.g. missing instances, etc) and
#initiates certain actions (e.g. restarting the missing instances)

module HealthManager2
  class Harmonizer
    def initialize(config = {})
      @config = config
      @logger = get_logger
    end

    def add_logger_listener(event)
      AppState.add_listener(event) do |*args|
        @logger.debug { "app_state: event: #{event}: #{args}" }
      end
    end

    def prepare
      @logger.debug { "harmonizer: #prepare" }

      [:live_version_changed,
       :num_instances_exceeded ].each { |event|
        add_logger_listener(event)
      }

      #set system-wide configurations
      AppState.analysis_delay_after_reset = get_interval_from_config_or_constant(:analysis_delay, @config)

      #set up listeners for anomalous events to respond with correcting actions
      AppState.add_listener(:instances_missing) do |app_state|
        @logger.debug { "harmonizer: instances_missing"}
        nudger.start_instances([[app_state,NORMAL_PRIORITY]])
      end

      AppState.add_listener(:instances_rogue) do |app_state, rogue_instance|
        @logger.debug { "harmonizer: instances_rogue: #{app_state}, rogue: #{rogue_instance}"}
        nudger.stop_instance(app_state,rogue_instance,NORMAL_PRIORITY)
      end

      AppState.add_listener(:exit_dea) do |app_state|
        @logger.debug { "harmonizer: exit_dea"}
        nudger.start_instances([[app_state,HIGH_PRIORITY]])
      end

      AppState.add_listener(:exit_crashed) do |app_state|
        @logger.debug { "harmonizer: exit_crashed"}
        nudger.start_instances([[app_state,LOW_PRIORITY]])
      end

      #schedule time-based actions
      scheduler.immediately { update_expected_state }

      scheduler.at_interval :request_queue do
        nudger.deque_batch_of_requests
      end

      scheduler.at_interval :expected_state_update do
        update_expected_state
      end

      scheduler.at_interval :droplet_analysis do
        analyze_all_apps
      end
    end

    private

    def analyze_all_apps
      @logger.debug { "harmonizer: droplet_analysis"}
      known_state_provider.rewind
      scheduler.start_task :droplet_analysis do
        known_droplet = known_state_provider.next_droplet
        if known_droplet
          known_droplet.analyze
          true
        else
          false
        end
      end
    end

    def update_expected_state
      @logger.debug { "harmonizer: expected_state_update"}
      expected_state_provider.each_droplet do |app_id, expected|
        known = known_state_provider.get_droplet(app_id)
        expected_state_provider.set_expected_state(known, expected)
      end
    end

    def scheduler
      find_hm_component(:scheduler, @config)
    end
    def nudger
      find_hm_component(:nudger, @config)
    end
    def known_state_provider
      find_hm_component(:known_state_provider, @config)
    end
    def expected_state_provider
      find_hm_component(:expected_state_provider, @config)
    end
  end
end
