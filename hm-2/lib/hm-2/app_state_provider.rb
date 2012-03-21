require 'set'

module HM2
  #base class for providing states of applications.  Concrete
  #implementations will use different data sources to obtain and/or
  #persists the state of apps.  This class serves as data holder and
  #interface provider for its users (i.e. HealthManager).
  class AppStateProvider
    include HM2::Common

    def initialize(config={})
      @config = config
      @droplets = {} #hashes droplet_id => AppState instance
      @cur_droplet_index = 0
      @logger = get_logger
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
      id = id.to_i
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
        klass = ::HM2.const_get(klass_name) if klass_name && ::HM2.const_defined?(klass_name)
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
