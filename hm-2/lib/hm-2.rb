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
require 'hm-2/common'
require 'hm-2/app_state'
require 'hm-2/app_state_provider'
require 'hm-2/nats_based_known_state_provider'
require 'hm-2/bulk_based_expected_state_provider'
require 'hm-2/scheduler'
require 'hm-2/nudger'
require 'hm-2/harmonizer'
require 'hm-2/varz'

module HM2
  class Manager
    include HM2::Common
    #primarily for testing
    attr_reader :scheduler
    attr_reader :known_state_provider
    attr_reader :expected_state_provider

    def initialize(config={})
      @config = config
      @logger = get_logger

      @logger.info("HM-2: HealthManager2 initializing")

      @varz = Varz.new(@config)
      @varz.setup_varz
      register_hm_component(:varz, @varz)

      @scheduler = Scheduler.new(@config)
      register_hm_component(:scheduler, @scheduler)

      @known_state_provider = AppStateProvider.get_known_state_provider(@config)
      register_hm_component(:known_state_provider, @known_state_provider)

      @expected_state_provider = AppStateProvider.get_expected_state_provider(@config)
      register_hm_component(:expected_state_provider, @expected_state_provider)

      @nudger = Nudger.new(@config)
      register_hm_component(:nudger, @nudger)

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
end
