require 'set'

module HealthManager2
  #this class provides answers about droplet's State
  class AppState
    class << self
      def known_event_types
        [:before_heartbeat,
         :after_heartbeat,
         :before_crash,
         :after_crash,
         :live_version_changed,
         :num_instances_exceeded,
         :instances_missing,
         :state_changed,]
      end
      def add_listener(event_type, &block)
        check_event_type(event_type)
        @listeners ||= {}
        @listeners[event_type] ||= []
        @listeners[event_type] << block
      end
      def notify_listener(event_type, app_state, *args)
        check_event_type(event_type)
        listeners = @listeners[event_type] || []
        listeners.each do |block|
          block.call(app_state, *args)
        end
      end
      def check_event_type(event_type)
        raise ArgumentError, "Unknown event type: #{event_type}" unless known_event_types.include?(event_type)
      end
      def remove_all_listeners
        @listeners = {}
      end
      attr_accessor :analysis_delay_after_reset
      attr_accessor :heartbeat_deadline
    end
    def initialize(id)
      @id = id
      @num_instances = 0
      @versions = {}
      @crashes = {}
      reset_missing_indices
    end
    attr_reader :id
    attr_accessor :state
    attr_accessor :live_version
    attr_accessor :num_instances
    attr_accessor :framework, :runtime
    attr_accessor :last_updated
    attr_accessor :versions, :crashes

    def notify(event_type, *args)
      #puts "EVENT: #{event_type} \@#{self.id}"
      self.class.notify_listener(event_type, self, *args)
    end
    def process_heartbeat(beat)
      notify :before_heartbeat, beat
      events = []

      if live_version != beat['version']
        events << [:live_version_changed, live_version, beat['version']]
        @live_version= beat['version']
      end

      if beat['index'] >= num_instances
        events << [:num_instances_exceeded, num_instances, beat['index']-1]
        @num_instances= beat['index'] + 1
      end
      if state != beat['state']
        events << [:state_changed, state, beat['state']]
        @state= beat['state']
      end
      #TODO: prevent uncapped growth, ensure clean-up
      index = get_index(beat['version'], beat['index'])
      index['last_heartbeat'] = now
      %w(instance state_timestamp state).each do |key|
        index[key] = beat[key]
      end

      events.each {|event| notify(*event)}
      notify :after_heartbeat, beat
    end

    def process_heartbeat_missed(latest_hb)
      check_for_missing_indices
    end
    def check_for_missing_indices
      unless reset_recently? or missing_indices.empty?
        notify :instances_missing,  missing_indices
        reset_missing_indices
      end
    end
    def reset_missing_indices
      @reset_timestamp = now
    end
    def missing_indices
      (0...num_instances).find_all { |i|
        lhb = get_index(live_version, i)['last_heartbeat']
        lhb.nil? || now > lhb + (AppState.heartbeat_deadline || 15)
      }
    end
    def num_instances= val
      @num_instances = val
      reset_missing_indices
      @num_instances
    end
    #check for all anomalies and trigger appropriate events so that listeners can take action
    def analyze
      check_for_missing_indices
    end
    def reset_recently?
      now - @reset_timestamp < (AppState.analysis_delay_after_reset || 0)
    end
    def process_exit_crash(message)
      notify :before_crash, message
      @state = CRASHED
      reset_missing_indices
      #TODO: save crash info in @crashes
      notify :afer_crash, message
    end
    def get_index(version, index)
      version = @versions[version] ||= {:indices=>{}}
      version[:indices][index] ||= {}
    end
  end

  #base class for providing states of applications.  Concrete
  #implementations will use different data sources to obtain and/or
  #persists the state of apps.  This class serves as data holder and
  #interface provider for its users (i.e. HealthManager).
  class AppStateProvider

    def initialize(config={})
      @config = config
      @droplets = {} #hashes droplet_id => AppState instance
      @cur_droplet_index = 0
      @logger = VCAP::Logging.logger('hm2')
    end
    def start; end
    #these methods have to do with threading and quantization
    def rewind
      @cur_droplet_index = 0
    end
    def next_droplet
      return nil unless @cur_droplet_index < @droplets.size
      droplet =  @droplets[@cur_droplet_index]
      @cur_droplet_index += 1
      return droplet
    end
    def add_droplet(droplet)
      @droplets[droplet.id] = droplet
    end
    def get_droplet(id)
      @droplets[id] ||= AppState.new(id)
    end
    def get_state(id)
      get_droplet(id).state
    end
    def set_state(id, state)
      get_droplet(id).state = state
    end
    class << self
      def get_known_state_provider(config={})
        new_configured_class(config, 'known_state_provider', NatsBasedKnownStateProvider)
      end
      def get_expected_state_provider(config={})
        new_configured_class(config, 'expected_state_provider', BulkBasedExpectedStateProvider)
      end
      def new_configured_class(config, config_key, default_class)
        klass_name = config[config_key] || config[config_key.to_s] || config[config_key.to_sym]
        klass = HealthManager2.const_get(klass_name) if klass_name && HealthManager2.const_defined?(klass_name)
        klass ||= default_class
        klass.new(config)
      end
    end
  end

  # "abstract" provider of expected state. Primarily for documenting the API
  class ExpectedStateProvider < AppStateProvider
    def set_expected_state(known, expected)
      raise 'Not Implemented' #should be implemented by the concerete class
    end
  end

  # "abstract" provider of known state. Primarily for documenting the API
  class KnownStateProvider < AppStateProvider
  end
end
