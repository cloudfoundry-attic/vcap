require 'json'

module HealthManager2
  #this class provides answers about droplet's State

  class AppState

    class << self
      def add_listener(event_type, &block)
        @listeners ||= {}
        @listeners[event_type] ||= []
        @listeners[event_type] << block
      end

      def notify_listener(event_type, app_state, *args)
        listeners = @listeners[event_type] || []
        listeners.each do |block|
          block.call(app_state, *args)
        end
      end

      def remove_all_listeners
        @listeners = {}
      end

    end


    def initialize(id)
      @id = id
      @instances = 0
      @versions = {}
      @crashes = {}
    end

    attr_reader :id
    attr_accessor :state
    attr_accessor :live_version
    attr_accessor :instances #number of instances
    attr_accessor :framework, :runtime
    attr_accessor :last_updated

    attr_accessor :versions, :crashes

    def notify(event_type, *args)
      self.class.notify_listener(event_type, self, *args)
    end

    def process_heartbeat beat
      notify :before_heartbeat, beat

      if live_version_changed?(beat['version'])
        notify :live_version_changed, beat
        @live_version = beat['version']
      end

      if beat['index'] >= @instances
        notify :instances_exceeded, beat
        @instances = beat['index'] - 1
      end

      if state_changed?( beat['state'] )
        notify :state_changed,
        @state = beat['state']
      end

      #TODO: prevent uncapped growth, ensure clean-up
      index = get_index(beat['version'], beat['index'])

      index['last_heartbeat'] = now
      %w(instance state_timestamp state).each do |key|
        index[key] = beat[key]
      end

      notify :after_heartbeat, beat
    end

    def process_exit_crash(message)
      notify :before_crash, message
      @state = CRASHED
      #TODO: save crash info in @crashes
      notify :afer_crash, message
    end

    def get_index(version, index)
      version = @versions[version] ||= {:indices=>{}}
      index = version[:indices][index] ||= {}
    end


    #just a little bit of meta-programming goodness
    def method_missing method, *args
      case method
      when /_changed\?$/
        has_attribute_changed?(method[0..-10], *args)
      else
        super(method, *args)
      end
    end

    def has_attribute_changed?(attribute, value)
      instance_variable_get("@#{attribute}") != value
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
    end

    #these methods have to do with threading and quantization
    def start; end
    def rewind; end


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
        new_configured_class(config, 'expected_state_provider', RestBasedExpectedStateProvider)
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
  end

  # "abstract" provider of known state. Primarily for documenting the API
  class KnownStateProvider < AppStateProvider
  end

  #this implementation will use a (yet non-existent) REST API to
  #interrogate the CloudController on the expected state of the apps
  #the API should allow for non-blocking operation
  class RestBasedExpectedStateProvider < ExpectedStateProvider
  end

  def now
    Time.now.to_i
  end

end
