require 'set'

module HM2
  #this class provides answers about droplet's State
  class AppState
    include HM2::Common
    class << self
      def known_event_types
        [:before_heartbeat,
         :after_heartbeat,
         :live_version_changed,
         :num_instances_exceeded,
         :instances_missing,
         :instances_rogue,
         :exit_crashed,
         :exit_stopped,
         :exit_dea,
        ]
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

      get_logger.debug { "app_state: #initialize: #{id}" }

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

      if @live_version != beat['version']
        events << [:live_version_changed, @live_version, beat['version']]
        @live_version= beat['version']
      end

      if beat['index'] >= @num_instances
        new_num_instances = beat['index'] + 1
        events << [:num_instances_exceeded, @num_instances, new_num_instances]
        @num_instances = new_num_instances
      end

      #TODO: prevent uncapped growth, ensure clean-up in analysis loop
      index = get_index(beat['version'], beat['index'])
      index['last_heartbeat'] = now

      if  index['state'] == RUNNING &&
          RUNNING_STATES.include?(beat['state']) &&
          index['instance'] != beat['instance']

        get_logger.info {"app_state: instance_mismatch: index: #{index}, beat: #{beat}"}
        events << [:instances_rogue, beat['instance']]
      else
        index['timestamp'] = now
        %w(instance state_timestamp state).each do |key|
          index[key] = beat[key]
        end
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
      @missing_indices = nil
      @reset_timestamp = now
    end
    def missing_indices
      return @missing_indices if @missing_indices

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
      get_logger.debug("app_state: #analyze")
      check_for_missing_indices
    end
    def reset_recently?
      now - @reset_timestamp < (AppState.analysis_delay_after_reset || 0)
    end

    def process_exit_dea(message)
      @missing_indices = [message['index']]
      @state = STOPPED
      notify(:exit_dea, message)
    end

    def process_exit_stopped(message)
      reset_missing_indices
      args = [:exit_stopped, state, STOPPED, message]
      @state = STOPPED
      notify(:exit_stopped, message)
    end

    def process_exit_crash(message)
      @missing_indices = [message['index']]
      get_index(message['version'],message['index'])['state'] = CRASHED
      #TODO: flapping logic, is it here?
      #NO, it must be externalized into harmonizer
      #TODO: save crash info in @crashes
      notify :exit_crashed, message
    end
    def get_index(version, index)
      version = @versions[version] ||= {:indices=>{}}
      version[:indices][index] ||= {}
    end
  end
end
