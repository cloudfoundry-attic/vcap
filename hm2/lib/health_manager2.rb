#The HealthManager 2.0:

require 'yajl'

require 'vcap/common'
require 'vcap/component'
require 'vcap/logging'
require 'vcap/priority_queue'
require 'nats/client'
require 'constants'
require 'app_state_provider'
require 'nats_based_known_state_provider'
require 'bulk_based_expected_state_provider'
require 'scheduler'
require 'nudger'
require 'harmonizer'

module HealthManager2

  class Manager
    #primarily for testing
    attr_reader :scheduler
    attr_reader :known_state_provider
    attr_reader :expected_state_provider

    def initialize(config={})
      @config = config
      @scheduler = Scheduler.new(config)
      register_hm_component(:scheduler, @scheduler, @config)

      @known_state_provider = AppStateProvider.get_known_state_provider(@config)
      @expected_state_provider = AppStateProvider.get_expected_state_provider(@config)

      @nudger = Nudger.new(@config)
      register_hm_component(:nudger, @nudger, @config)
      @harmonizer = Harmonizer.new(@config)
    end
    def prepare
      @harmonizer.prepare
    end
    def start
      @scheduler.start
    end

    #The setter for @now this is defined in the spec helper
    #and is used exclusively for testing
    def self.now
      @now || Time.now.to_i
    end
  end
  def now
    Manager.now
  end
  def get_interval_from_config_or_constant(name, config)
    intervals = config[:intervals] || config['intervals'] || {}
    get_param_from_config_or_constant(name,intervals)
  end

  def get_param_from_config_or_constant(name, config)
    value = config[name] || config[name.to_sym] || config[name.to_s]
    unless value
      const_name = name.to_s.upcase
      if HealthManager2.const_defined?( const_name )
        value = HealthManager2.const_get( const_name )
      end
    end
    raise ArgumentError, "undefined parameter #{name}" unless value
    value
  end
  def find_hm_component(name, config)
    unless component = hm_registry(config)[name]
      raise ArgumentError, "component #{name} can't be found in the registry #{config}"
    end
    component
  end
  def register_hm_component(name, component, config)
    hm_registry(config)[name] = component
  end
  def hm_registry(config)
    config[:health_manager_component_registry] ||= {}
  end
  def encode_json(obj={})
    Yajl::Encoder.encode(obj)
  end
  def parse_json(string='{}')
    Yajl::Parser.parse(string)
  end
end
