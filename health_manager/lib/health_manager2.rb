#The HealthManager 2.0:
#goals:
#1. de-couple HealthManager from CloudController's ActiveRecord-based models and database
#2. improve maintainability

#HM "harmonizes" the "Expected State" and the "Known State" of applications.

#The Expected state will be discovered from an instance of
#ExpectedStateProvider class, that will have Http-based implementation
#(and perhaps DbBased implementation for testing and compatibility
#reasons)

#The Known state will be discovered from NatsBasedKnownStateProvider,
#that will listen to heartbeat and other messages and maintain and
#update the known state

#the goal of "harmonization" is to nudge the known state to correspond exactly to
#the expected state

#the "harmonization" involves evaluating a set of
#conditions (e.g. presence of crashed or unknown applications), and initiating
#corresponding actions, such as sending start/stop requests,
#StateProvider refreshes, statistics collection/reporting, etc.

#the harmonization attempts should allow to: a) be triggered at configurable
#time intervals; b) be initiated by events like dea messages; c) allow for throttling, to
#avoid flooding the system with start/stop requests

#the scheduling semantics are extracted into a "Scheduler"

#the harmonization semantics are extracted into a Harmonizer

#the Harmonizer actuates the harmonizing action using a "Nudger"

#the Nudger is responsible for effecting the action that Harmonizer
#determines

#the Manager is the orchestrating component that does intialization,
#setup, termination, cleanup, client interfacing, etc.  Most of this
#is achieved through delegation

require 'constants.rb'
require 'app_state_provider.rb'
require 'scheduler.rb'
require 'nudger.rb'

module HealthManager2
  class Harmonizer; end

  class Manager

    #primarily for testing
    attr_reader :scheduler

    def initialize(config={})
      @config = config

      @known_state_provider = AppStateProvider.new(config)
      @expected_state_provider = AppStateProvider.new(config)
      @scheduler = Scheduler.new(config)
      @harmonizer = Harmonizer.new(config)
      @nudger = Nudger.new(config)

      @running_tasks = {}
    end

    def schedule
      at_interval :nats_ping do
        @nudger.publish_ping
      end

      at_interval :expected_state_update do
        start_expected_state_update unless task_running? :expected_state_update
      end

      at_interval :droplet_analysis do


      end

    end

    def start
      @scheduler.start
    end

    #private
    def start_expected_state_update
      mark_task_started(:expected_state_update)

      @expected_state_provider.rewind

      quantize_task do

        puts 'QUANTUM: expected state update'
        if droplet = @expected_state_provider.next_droplet
          droplet.update
        else
          mark_task_stopped(:expected_state_provider)
          false
        end
      end
    end

    def quantize_task
      immediately(yield) unless yield
    end

    def mark_task_started(task)
      @running_task[task] = :started
    end

    def mark_task_stopped(task)
      raise ArgumentError, "task #{task} not started" unless @running_task.delete(task)
    end

    def task_running?(task)
      @running_tasks[task] == :started
    end

    def immediately(&block)
      @scheduler.schedule(:immediate => true, &block)
    end

    def after_interval(interval_name, &block)
      @scheduler.schedule(:timer => get_interval(interval_name), &block)
    end

    def at_interval(interval_name, &block)
      @scheduler.schedule(:periodic => get_interval(interval_name), &block)
    end

    def get_interval(name)
      intervals = @config[:intervals] || @config['intervals'] || {}
      interval = intervals[name] || intervals[name.to_sym] || intervals[name.to_s]
      unless interval
        const_name = name.to_s.upcase
        if HealthManager2.const_defined?( const_name )
          interval = HealthManager2.const_get( const_name )
        end
      end
      raise ArgumentError, "undefined interval #{name}" unless interval
      interval
    end
  end
end
