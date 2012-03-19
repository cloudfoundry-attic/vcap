#hm-2 -- HealthManager 2.0. (c) 2011-2012 VMware, Inc.
$:.unshift(File.dirname(__FILE__))

require 'yajl'
require 'time'
require 'nats/client'

require 'vcap/common'
require 'vcap/component'
require 'vcap/logging'
require 'vcap/priority_queue'

require 'hm-2/constants'
require 'hm-2/app_state_provider'
require 'hm-2/nats_based_known_state_provider'
require 'hm-2/bulk_based_expected_state_provider'
require 'hm-2/scheduler'
require 'hm-2/nudger'
require 'hm-2/harmonizer'

module HealthManager2

  class Manager
    #primarily for testing
    attr_reader :scheduler
    attr_reader :known_state_provider
    attr_reader :expected_state_provider

    def initialize(config={})
      @config = config
      @logger = get_logger

      @logger.info("HM-2: HealthManager2 initializing")

      @scheduler = Scheduler.new(config)
      register_hm_component(:scheduler, @scheduler, @config)

      @known_state_provider = AppStateProvider.get_known_state_provider(@config)
      register_hm_component(:known_state_provider, @known_state_provider, @config)

      @expected_state_provider = AppStateProvider.get_expected_state_provider(@config)
      register_hm_component(:expected_state_provider, @expected_state_provider, @config)

      @nudger = Nudger.new(@config)
      register_hm_component(:nudger, @nudger, @config)
      @harmonizer = Harmonizer.new(@config)
    end

    def start
      @logger.info("starting...")

      NATS.start :uri => ENV[NATS_URI] || 'nats://nats:nats@192.168.24.128:4222' do #TODO: nats_uri through config
        @harmonizer.prepare
        @expected_state_provider.start
        @known_state_provider.start

        unless ENV[HM_SHADOW]=='false'
          @logger.info("creating Shadower")
          @shadower = Shadower.new(@config)
          @shadower.subscribe
        end

        @scheduler.start #blocking call
      end
    end

    def shutdown
      @logger.info("shutting down...")
      NATS.stop { EM.stop }
      @logger.info("...good bye.")
    end

    #The setter for @now is defined in the spec helper
    #and is used exclusively for testing
    def self.now
      @now || Time.now.to_i
    end
  end

  def now
    Manager.now
  end

  def parse_utc(time)
    Time.parse(time).to_i
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

  def register_hm_component(name, component, config)
    hm_registry(config)[name] = component
  end

  def find_hm_component(name, config)
    unless component = hm_registry(config)[name]
      raise ArgumentError, "component #{name} can't be found in the registry #{config}"
    end
    component
  end

  def get_logger(name='hm-2')
    VCAP::Logging.logger(name)
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
