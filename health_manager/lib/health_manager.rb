# Copyright (c) 2009-2011 VMware, Inc.
module CloudController
  require 'pathname'
  require 'erb'
  require 'yaml'
  require 'fileutils'
  require 'logger'
  require 'optparse'
  require 'set'

  def self.root
    @root ||= Pathname.new(File.expand_path('../../../cloud_controller', __FILE__))
  end

  def self.lib_dir
    root.join('lib')
  end

  # NOTE - Any models that rely on appconfig.yml settings must likewise
  # be initialized by the Health Manager before they are used.
  def self.all_models
    Dir.glob(root.join('app', 'models', '*.rb'))
  end

  def self.setup
    $:.unshift(lib_dir.to_s) unless $:.include?(lib_dir.to_s)
    require root.join('config', 'boot')
    require 'active_record'
    require 'active_support/core_ext'
    require 'yajl'
    require 'eventmachine'
    require 'nats/client'
    require 'vcap/common'
    require 'vcap/component'
    require 'vcap/logging'
    require 'vcap/rolling_metric'
    require 'vcap/priority_queue'
    all_models.each {|fn| require(fn)}

    # This is needed for comparisons between the last_updated time of an app and the current time
    # Time.zone = :utc
    ActiveRecord::Base.time_zone_aware_attributes = true
    ActiveRecord::Base.default_timezone = :utc
  end

  def self.load_yaml(path)
    File.open(path, 'rb') do |fh|
      yaml = ERB.new(fh.read).result(binding)
      return YAML.load(yaml)
    end
  end
end

CloudController.setup
class HealthManager
  VERSION = 0.98

  attr_reader :database_scan, :droplet_lost, :droplets_analysis, :flapping_death, :flapping_timeout
  attr_reader :restart_timeout, :stable_state, :droplets
  attr_reader :request_queue

  # TODO - Oh these need comments so badly..
  DOWN              = 'DOWN'
  STARTED           = 'STARTED'
  STOPPED           = 'STOPPED'
  CRASHED           = 'CRASHED'
  STARTING          = 'STARTING'
  RUNNING           = 'RUNNING'
  FLAPPING          = 'FLAPPING'
  DEA_SHUTDOWN      = 'DEA_SHUTDOWN'
  DEA_EVACUATION    = 'DEA_EVACUATION'
  APP_STABLE_STATES = Set.new([STARTED, STOPPED])
  RUNNING_STATES    = Set.new([STARTING, RUNNING])
  RESTART_REASONS   = Set.new([CRASHED, DEA_SHUTDOWN, DEA_EVACUATION])


  INFINITE_PRIORITY = 2_000_000_000


  def self.start(options)
    health_manager = new(options)
    health_manager.run
    health_manager
  end

  def initialize(config)
    @config = config
    VCAP::Logging.setup_from_config(config['logging'])
    @logger = VCAP::Logging.logger('hm')
    @database_scan = config['intervals']['database_scan']
    @droplet_lost = config['intervals']['droplet_lost']
    @droplets_analysis = config['intervals']['droplets_analysis'] || 10
    @flapping_death = config['intervals']['flapping_death']
    @flapping_timeout = config['intervals']['flapping_timeout']
    @restart_timeout = config['intervals']['restart_timeout']
    @stable_state = config['intervals']['stable_state']
    @max_db_reconnect_wait = config['intervals']['max_db_reconnect_wait'] || 300 #up to five minutes by default
    @dequeueing_rate = config['dequeueing_rate'] || 50
    @database_environment = config['database_environment']

    @droplets = {}
    @request_queue = VCAP::PrioritySet.new

    configure_database

    if config['pid']
      @pid_file = config['pid']
      # Create pid file
      begin
        FileUtils.mkdir_p(File.dirname(@pid_file))
      rescue => e
        @logger.fatal "Can't create pid directory, exiting: #{e}"
      end
      File.open(@pid_file, 'wb') { |f| f.puts "#{Process.pid}" }
    end
  end

  def encode_json(obj = {})
    Yajl::Encoder.encode(obj)
  end

  def parse_json(string = '{}')
    Yajl::Parser.parse(string)
  end

  def create_droplet_entry
    { :versions => {}, :crashes => {} }
  end

  def create_index_entry
    { :last_action => -1, :crashes => 0, :crash_timestamp => -1 }
  end

  def create_version_entry
    { :indices => {} }
  end

  def run
    @started = Time.now.to_i
    NATS.on_error do |e|
      @logger.error("NATS problem, #{e}")
      @logger.error(e)
      exit!
    end
    EM.error_handler do |e|
      @logger.error "Eventmachine problem, #{e}"
      @logger.error(e)
      exit!
    end

    NATS.start(:uri => @config['mbus']) do
      configure_timers
      register_as_component
      subscribe_to_messages
    end
  end

  # We use the CloudController database configuration
  # if none is specified in our config file.
  # By default, we connect to the development database.
  def configure_database
    env = @config['rails_environment'] || CloudController.environment
    if @database_environment
      config = @database_environment[env]
    else
      # using CloudController db configuration
      config = AppConfig[:database_environment][env]
    end
    logger = Logger.new(STDOUT)
    logger.level = Logger::INFO
    establish_database_connection(config, logger)
  end

  def ensure_connected(&block)
    sleep_time = 1
    total_sleep_time = 0
    failure_count = 0
    begin
      yield
    rescue ActiveRecord::StatementInvalid
      # This exception is raised when a connection was previously connected, but
      # upon executing a statement detects that the connection is actually gone.
      # Calling #disconnect! on the connection pool will make it reconnect.
      @logger.warn('Possibly lost db connection, attempting to re-connect')
      ActiveRecord::Base.connection_pool.disconnect!
      retry
    rescue ActiveSupport::Dependencies::Blamable => e
      @logger.warn("Attempting to recover from: #{e}")
      failure_count += 1
      if total_sleep_time < @max_db_reconnect_wait
        @logger.warn("Waiting for #{sleep_time} seconds before re-attempting database operation")
        sleep sleep_time
        total_sleep_time += sleep_time
        sleep_time *= 2 unless sleep_time > 60
        retry
      else
        @logger.error("Unable to reconnect after #{failure_count} attempts over #{total_sleep_time} seconds of waiting, giving up. Error information follows.")
        @logger.error(e)
        exit!
      end
    end
  end

  def establish_database_connection(db_config, logger)
    expand_database_path_for_sqlite3(db_config)
    ActiveRecord::Base.establish_connection(db_config)
    ActiveRecord::Base.logger = logger
    logger.debug "Connected to CloudController database"
  end

  # If the adapter is sqlite3 and the path is relative, expand it
  # in reference to the CloudController root.
  def expand_database_path_for_sqlite3(db_config)
    if db_config['adapter'] == 'sqlite3'
      db_path = db_config['database']
      unless db_path[0,1] == '/'
        db_path = File.join(CloudController.root, db_path)
      end
      db_config['database'] = File.expand_path(db_path)
    end
  end

  def shutdown
    @logger.info('Shutting down.')
    FileUtils.rm_f(@pid_file) if @pid_file
    NATS.stop { EM.stop }
  end

  def analyze_app(app_id, droplet_entry, stats)
    now = Time.now.to_i
    update_timestamp = droplet_entry[:last_updated]
    quiescent = (now - update_timestamp) > @stable_state
    if APP_STABLE_STATES.include?(droplet_entry[:state]) && quiescent
      extra_instances = []
      missing_indices = []

      droplet_entry[:crashes].delete_if do |_, crash_entry|
        now - crash_entry[:timestamp] > @droplet_lost
      end

      droplet_entry[:versions].delete_if do |version, version_entry|
        version_entry[:indices].delete_if do |index, index_entry|
          if RUNNING_STATES.include?(index_entry[:state]) && now - index_entry[:timestamp] > @droplet_lost
            index_entry[:state] = DOWN
            index_entry[:state_timestamp] = now
          end

          reason = nil
          if droplet_entry[:state] == STOPPED
            extra_instance = true
            reason = "Droplet state is STOPPED."
          elsif index >= droplet_entry[:instances]
            extra_instance = true
            reason = "Extra instance. Droplet should have #{droplet_entry[:instances]} instances running."
          elsif version != droplet_entry[:live_version]
            extra_instance = true
            reason = "Live version mismatch. Live version is #{droplet_entry[:live_version]} instance version is #{version}."
          end

          if RUNNING_STATES.include?(index_entry[:state]) && extra_instance
            @logger.info("Preparing to stop instance (app_id=#{app_id}, index=#{index}, instance=#{index_entry[:instance]}). Reason: #{reason}")
            extra_instances << index_entry[:instance]
          elsif extra_instance
            # stop tracking extra instances
            true
          end
        end

        # delete empty version entries for non live versions
        if version_entry[:indices].empty?
          droplet_entry[:state] == STOPPED || version != droplet_entry[:live_version]
        end
      end

      if droplet_entry[:state] == STARTED
        live_version_entry = droplet_entry[:versions][droplet_entry[:live_version]] || create_version_entry

        framework_stats = stats[:frameworks][droplet_entry[:framework]] ||= create_runtime_metrics
        runtime_stats = stats[:runtimes][droplet_entry[:runtime]] ||= create_runtime_metrics

        framework_stats[:apps] += 1
        runtime_stats[:apps] += 1

        framework_stats[:crashes] += droplet_entry[:crashes].length
        runtime_stats[:crashes] += droplet_entry[:crashes].length

        index_entries = live_version_entry[:indices]
        droplet_entry[:instances].times do |index|
          index_entry = index_entries[index]
          unless index_entry
            index_entry = index_entries[index] = create_index_entry
            index_entry[:state] = DOWN
            index_entry[:state_timestamp] = now
          end

          if RUNNING_STATES.include?(index_entry[:state])
            stats[:running] += 1
            framework_stats[:running_instances] += 1
            runtime_stats[:running_instances] += 1
          elsif index_entry[:state] == DOWN
            stats[:down] += 1 if index_entry[:state] == DOWN
            framework_stats[:missing_instances] += 1
            runtime_stats[:missing_instances] += 1
          elsif index_entry[:state] == FLAPPING
            framework_stats[:flapping_instances] += 1
            runtime_stats[:flapping_instances] += 1
          end

          if index_entry[:state] == DOWN && now - index_entry[:last_action] > @restart_timeout
            @logger.info("Preparing to restart instance (app_id=#{app_id}, index=#{index}). Reason: droplet state is STARTED, but instance state is DOWN.")
            index_entry[:last_action] = now
            missing_indices << index
          end
        end
      end

      ensure_connected do
        # don't act if we were looking at a stale droplet
        if update_droplet(App.find_by_id(app_id))
          if missing_indices.any? || extra_instances.any?
            @logger.info("Droplet information is stale for app id #{app_id}, not taking action.")
            @logger.info("(#{missing_indices.length} instances need to be started, #{extra_instances.length} instances need to be stopped.)")
          end
          return
        end
      end

      if missing_indices.any?
        start_instances(app_id, missing_indices)
      end
      if extra_instances.any?
        stop_instances(app_id, extra_instances)
      end
    end
  end


  def prepare_analysis(collect_stats)
    @analysis = {
      :collect_stats => collect_stats,
      :start => Time.now,
      :instances => 0,
      :crashed => 0,
      :stats => {:running => 0, :down => 0, :frameworks => {}, :runtimes => {}},
      :ids => @droplets.keys,
      :current_key_index => 0
    }
  end

  def analysis_in_progress?
    @analysis && !@analysis[:complete]
  end

  def perform_quantum(id, droplet_entry)
    return if id.nil?
    return if droplet_entry.nil?

    analyze_app(id, droplet_entry, @analysis[:stats]) if @analysis[:collect_stats]
    @analysis[:instances] += droplet_entry[:instances]
    @analysis[:crashed] += droplet_entry[:crashes].size if droplet_entry[:crashes]
  end

  def perform_and_schedule_next_quantum

    if @analysis[:current_key_index] < @analysis[:ids].size
      perform_quantum(
                      @analysis[:ids][@analysis[:current_key_index]],
                      @droplets[@analysis[:ids][@analysis[:current_key_index]]])

      @analysis[:current_key_index] += 1

      EM.next_tick {
        perform_and_schedule_next_quantum
      }
    else
      finish_analysis
    end
  end

  def finish_analysis

    return unless @analysis
    @logger.debug("Analysis complete: #{@analysis.inspect}")
    VCAP::Component.varz[:total_apps] = @droplets.size
    VCAP::Component.varz[:total_instances] = @analysis[:instances]
    VCAP::Component.varz[:crashed_instances] = @analysis[:crashed]

    if @analysis[:collect_stats]
      VCAP::Component.varz[:running_instances] = @analysis[:stats][:running]
      VCAP::Component.varz[:down_instances] = @analysis[:stats][:down]
      VCAP::Component.varz[:running][:frameworks] = @analysis[:stats][:frameworks]
      VCAP::Component.varz[:running][:runtimes] = @analysis[:stats][:runtimes]
      @logger.info("Analyzed #{@analysis[:stats][:running]} running and #{@analysis[:stats][:down]} down apps in #{elapsed_time_in_ms(@analysis[:start])}")
    else
      @logger.info("Analyzed #{@droplets.size} apps in #{elapsed_time_in_ms(@analysis[:start])}")
    end
    @analysis[:complete] = true
  end

  def analyze_all_apps(collect_stats = true)

    return false if analysis_in_progress?

    prepare_analysis(collect_stats)
    perform_and_schedule_next_quantum
    return true
  end

  def create_runtime_metrics
    {
      :apps => 0,
      :crashes => 0,
      :running_instances => 0,
      :missing_instances => 0,
      :flapping_instances => 0
    }
  end

  def create_db_metrics
    {
      :apps => 0,
      :started_apps => 0,
      :instances => 0,
      :started_instances => 0,
      :memory => 0,
      :started_memory => 0
    }
  end

  def elapsed_time_in_ms(start)
    elapsed_ms = (Time.now - start) * 1000
    "#{'%.1f' % elapsed_ms}ms"
  end

  def process_updated_message(message)
    VCAP::Component.varz[:droplet_updated_msgs_received] += 1
    droplet_id = parse_json(message)['droplet']
    ensure_connected { update_droplet App.find_by_id(droplet_id) }
  end

  def process_exited_message(message)
    VCAP::Component.varz[:droplet_exited_msgs_received] += 1
    now = Time.now.to_i

    exit_message = parse_json(message)
    droplet_id = exit_message['droplet']
    version = exit_message['version']
    index = exit_message['index']
    instance = exit_message['instance']

    droplet_entry = @droplets[droplet_id]
    index_entry = nil

    if droplet_entry
      version_entry = droplet_entry[:versions][version]
      if version_entry
        index_entry = version_entry[:indices][index]
      end

      if version == droplet_entry[:live_version] && index >= 0 && index < droplet_entry[:instances]
        unless version_entry
          version_entry = droplet_entry[:versions][version] = create_version_entry
        end

        unless index_entry
          index_entry = version_entry[:indices][index] = create_index_entry
          index_entry[:instance] = instance
        end

        if index_entry[:instance].nil? || index_entry[:instance] == instance ||
            !RUNNING_STATES.include?(index_entry[:state])
          if RESTART_REASONS.include?(exit_message['reason'])
            if index_entry[:crash_timestamp] > 0 && now - index_entry[:crash_timestamp] > @flapping_timeout
              index_entry[:crashes] = 0
              index_entry[:crash_timestamp] = -1
            end

            if exit_message['reason'] == CRASHED
              index_entry[:crashes] += 1
              index_entry[:crash_timestamp] = now
            end

            if index_entry[:crashes] > @flapping_death
              index_entry[:state] = FLAPPING
              index_entry[:state_timestamp] = Time.now.to_i
              @logger.info("Giving up on flapping instance (app_id=#{droplet_id}, index=#{index}). Number of crashes: #{index_entry[:crashes]}.")
            else
              index_entry[:state] = DOWN
              index_entry[:state_timestamp] = Time.now.to_i
              index_entry[:last_action] = now

              high_priority = (exit_message['reason'] == DEA_EVACUATION)

              @logger.info("Preparing to start instance (app_id=#{droplet_id}, index=#{index}). Reason: Instance exited with reason '#{exit_message['reason']}'.")
              start_instances(droplet_id, [index], high_priority)
            end
          end
        end
      elsif index_entry
        version_entry[:indices].delete(index)
        droplet_entry[:versions].delete(version) if version_entry[:indices].empty?
      end

      if exit_message['reason'] == CRASHED
        droplet_entry[:crashes][instance] = {
          :timestamp => Time.now.to_i,
          :crash_timestamp => exit_message['crash_timestamp']
        }
      end
    end

    droplet_entry # return the droplet that we changed. This allows the spec tests to ensure the behaviour is correct.
  end

  def process_heartbeat_message(message)
    VCAP::Component.varz[:heartbeat_msgs_received] += 1
    result = []
    parse_json(message)['droplets'].each do |heartbeat|
      droplet_id = heartbeat['droplet']
      instance = heartbeat['instance']
      droplet_entry = @droplets[droplet_id]
      if droplet_entry
        result << droplet_entry
        state = heartbeat['state']
        if RUNNING_STATES.include?(state)
          version_entry = droplet_entry[:versions][heartbeat['version']]
          unless version_entry
            version_entry = droplet_entry[:versions][heartbeat['version']] = create_version_entry
          end

          index_entry = version_entry[:indices][heartbeat['index']]
          unless index_entry
            index_entry = version_entry[:indices][heartbeat['index']] = create_index_entry
          end

          if index_entry[:state] == RUNNING && index_entry[:instance] != instance
            stop_instances(droplet_id, [instance])
          else
            index_entry[:instance] = instance
            index_entry[:timestamp] = Time.now.to_i
            index_entry[:state] = state.to_s
            index_entry[:state_timestamp] = heartbeat['state_timestamp']
          end
        elsif state == CRASHED
          droplet_entry[:crashes][instance] = {
            :timestamp => Time.now.to_i,
            :crash_timestamp => heartbeat['state_timestamp']
          }
        end
      else
        instance_uptime = Time.now.to_i - heartbeat['state_timestamp']
        health_manager_uptime = Time.now.to_i - @started
        threshold = @database_scan * 2

        if health_manager_uptime > threshold && instance_uptime > threshold
          @logger.info("Stopping unknown app: #{droplet_id}/#{instance}.")
          stop_instances(droplet_id, [instance])
        end
      end
    end

    result # return the droplets that we changed. This allows the spec tests to ensure the behaviour is correct.
  end

  def process_health_message(message, reply)
    VCAP::Component.varz[:healthmanager_health_request_msgs_received] += 1
    message_json = parse_json(message)
    droplets = message_json['droplets']
    exchange = message_json['exchange']
    droplets.each do |droplet|
      droplet_id = droplet['droplet']

      droplet_entry = @droplets[droplet_id]
      if droplet_entry
        version = droplet['version']
        version_entry = droplet_entry[:versions][version]
        running = 0
        if version_entry
          version_entry[:indices].each_value do |index_entry|
            running += 1 if index_entry[:state] == RUNNING
          end
        end

        response_json = encode_json(:droplet => droplet_id, :version => version, :healthy => running)
        NATS.publish(reply, response_json)
      end
    end
  end

  def process_status_message(message, reply)
    VCAP::Component.varz[:healthmanager_status_msgs_received] += 1
    message_json = JSON.parse(message)
    droplet_id = message_json['droplet']
    droplet_entry = @droplets[droplet_id]

    if droplet_entry
      state = message_json['state']
      if state == FLAPPING
        version = message_json['version']
        result = []
        version_entry = droplet_entry[:versions][version]
        if version_entry
          version_entry[:indices].each do |index, index_entry|
            if index_entry[:state] == FLAPPING
              result << {
                :index => index,
                :since => index_entry[:state_timestamp]
              }
            end
          end
        end
        NATS.publish(reply, {:indices => result}.to_json)

      elsif state == CRASHED
        result = []
        droplet_entry[:crashes].each do |instance, crash_entry|
          result << {
            :instance => instance,
            :since => crash_entry[:crash_timestamp]
          }
        end
        NATS.publish(reply, {:instances => result}.to_json)
      end
    end
  end

  def update_from_db
    ensure_connected do
      start = Time.now
      old_droplet_ids = Set.new(@droplets.keys)

      App.all.each do |droplet|
        old_droplet_ids.delete(droplet.id)
        update_droplet(droplet)
      end

      old_droplet_ids.each {|id| @droplets.delete(id)}
      # TODO - Devise a version of the below that works with vast numbers of apps and users.
      VCAP::Component.varz[:total_users] = User.count
      VCAP::Component.varz[:users] = User.all_email_addresses.map {|e| {:email => e}}
      VCAP::Component.varz[:apps] = App.health_manager_representations
      @logger.info("Database scan took #{elapsed_time_in_ms(start)} and found #{@droplets.size} apps")

      start = Time.now

      VCAP::Component.varz[:total] = {
        :frameworks => {},
        :runtimes => {}
      }

      App.count(:group => ["framework", "runtime", "state"]).each do |grouping, count|
        framework, runtime, state = grouping

        framework_stats = VCAP::Component.varz[:total][:frameworks][framework] ||= create_db_metrics
        framework_stats[:apps] += count
        framework_stats[:started_apps] += count if state == "STARTED"

        runtime_stats = VCAP::Component.varz[:total][:runtimes][runtime] ||= create_db_metrics
        runtime_stats[:apps] += count
        runtime_stats[:started_apps] += count if state == "STARTED"
      end

      App.sum(:instances, :group => ["framework", "runtime", "state"]).each do |grouping, count|
        framework, runtime, state = grouping

        framework_stats = VCAP::Component.varz[:total][:frameworks][framework] ||= create_db_metrics
        framework_stats[:instances] += count
        framework_stats[:started_instances] += count if state == "STARTED"

        runtime_stats = VCAP::Component.varz[:total][:runtimes][runtime] ||= create_db_metrics
        runtime_stats[:instances] += count
        runtime_stats[:started_instances] += count if state == "STARTED"
      end

      App.sum("instances * memory", :group => ["framework", "runtime", "state"]).each do |grouping, count|
        # memory is stored as a string
        count = count.to_i
        framework, runtime, state = grouping

        framework_stats = VCAP::Component.varz[:total][:frameworks][framework] ||= create_db_metrics
        framework_stats[:memory] += count
        framework_stats[:started_memory] += count if state == "STARTED"


        runtime_stats = VCAP::Component.varz[:total][:runtimes][runtime] ||= create_db_metrics
        runtime_stats[:memory] += count
        runtime_stats[:started_memory] += count if state == "STARTED"
      end

      @logger.info("Database stat scan took #{elapsed_time_in_ms(start)}")
    end
  end

  def droplet_version(droplet)
    "#{droplet.staged_package_hash}-#{droplet.run_count}"
  end

  def update_droplet(droplet)
    return true unless droplet

    droplet_entry = @droplets[droplet.id]
    unless droplet_entry
      droplet_entry = create_droplet_entry
      @droplets[droplet.id] = droplet_entry
    end
    entry_updated = droplet_entry[:last_updated] != droplet.last_updated

    droplet_entry[:instances] = droplet.instances
    droplet_entry[:framework] = droplet.framework
    droplet_entry[:runtime] = droplet.runtime
    droplet_entry[:state] = droplet.state.upcase
    droplet_entry[:last_updated] = droplet.last_updated
    droplet_entry[:live_version] = droplet_version(droplet)

    entry_updated
  end

  def start_instances(droplet_id, indices, high_priority = false)
    droplet_entry = @droplets[droplet_id]
    start_message = {
      :droplet => droplet_id,
      :op => :START,
      :last_updated => droplet_entry[:last_updated],
      :version => droplet_entry[:live_version],
      :indices => indices
    }

    if queue_requests?
      queue_request(start_message, high_priority)
    else
      #old behavior: send the message immediately
      NATS.publish('cloudcontrollers.hm.requests', start_message.to_json)
      @logger.info("Requesting the start of extra instances: #{start_message}")
    end
  end

  def queue_request(message, high_priority)
    #the priority is higher for older items, to de-prioritize flapping items
    priority = Time.now.to_i - message[:last_updated]
    priority = 0 if priority < 0 #avoid timezone drama
    priority = INFINITE_PRIORITY if high_priority
    key = message.clone
    key.delete :last_updated
    @logger.info("Queueing priority '#{priority}' request: #{message}, using key: #{key}.  Queue size: #{@request_queue.size}")
    @request_queue.insert(message, priority, key)
  end

  def stop_instances(droplet_id, instances)
    droplet_entry = @droplets[droplet_id]
    last_updated = droplet_entry ? droplet_entry[:last_updated] : 0
    stop_message = {
      :droplet => droplet_id,
      :op => :STOP,
      :last_updated => last_updated,
      :instances => instances
    }.to_json
    NATS.publish('cloudcontrollers.hm.requests', stop_message)
    @logger.info("Requesting the stop of extra instances: #{stop_message}")
  end

  def configure_timers
    EM.next_tick { update_from_db }
    EM.add_periodic_timer(@database_scan) { update_from_db }

    # Do first pass without the individual analysis
    EM.next_tick { analyze_all_apps(collect_stats = false) }

    # Start the droplet analysis timer after the droplet lost timeout to make sure all the heartbeats came in.
    EM.add_timer(@droplet_lost) do
      EM.add_periodic_timer(@droplets_analysis) { analyze_all_apps }
    end

    if queue_requests?
      EM.add_periodic_timer(1) do
        deque_a_batch_of_requests
      end
    end
  end

  def deque_a_batch_of_requests(num_requests=@dequeueing_rate)
    num_requests.times do
      unless @request_queue.empty?
        #TODO: if STOP requests are also queued, refactor this to be generic, particularly the log message
        start_message = encode_json(@request_queue.remove)
        NATS.publish('cloudcontrollers.hm.requests', start_message)
        @logger.info("Requesting the start of missing instances: #{start_message}")
        VCAP::Component.varz[:queue_length] = @request_queue.size
      end
    end
  end

  def register_as_component
    status_config = @config['status'] || {}
    VCAP::Component.register(:type => 'HealthManager',
                             :host => VCAP.local_ip(@config['local_route']),
                             :index => @config['index'],
                             :config => @config,
                             :port => status_config['port'],
                             :user => status_config['user'],
                             :password => status_config['password'])

    # Initialize VCAP component varzs..
    VCAP::Component.varz[:total_apps] = 0
    VCAP::Component.varz[:total_users] = 0
    VCAP::Component.varz[:total_instances] = 0

    # These will get processed after a small delay..
    VCAP::Component.varz[:running_instances] = -1
    VCAP::Component.varz[:crashed_instances] = -1

    VCAP::Component.varz[:down_instances]    = -1

    VCAP::Component.varz[:queue_length] = 0

    VCAP::Component.varz[:total] = {
      :frameworks => {},
      :runtimes => {}
    }

    VCAP::Component.varz[:running] = {
      :frameworks => {},
      :runtimes => {}
    }

    VCAP::Component.varz[:heartbeat_msgs_received] = 0
    VCAP::Component.varz[:droplet_exited_msgs_received] = 0
    VCAP::Component.varz[:droplet_updated_msgs_received] = 0
    VCAP::Component.varz[:healthmanager_status_msgs_received] = 0
    VCAP::Component.varz[:healthmanager_health_request_msgs_received] = 0
    @logger.info("Starting VCAP Health Manager (#{VERSION})")
  end

  def subscribe_to_messages
    # Now we have something worth cleaning up at shutdown.
    trap('TERM') { shutdown }
    trap('INT') { shutdown }

    NATS.subscribe('dea.heartbeat') do |message|
      @logger.debug("heartbeat: #{message}")
      process_heartbeat_message(message)
    end

    NATS.subscribe('droplet.exited') do |message|
      @logger.debug("droplet.exited: #{message}")
      process_exited_message(message)
    end

    NATS.subscribe('droplet.updated') do |message|
      @logger.debug("droplet.updated: #{message}")
      process_updated_message(message)
    end

    NATS.subscribe('healthmanager.status') do |message, reply|
      @logger.debug("healthmanager.status: #{message}")
      process_status_message(message, reply)
    end

    NATS.subscribe('healthmanager.health') do |message, reply|
      @logger.debug("healthmanager.health: #{message}")
      process_health_message(message, reply)
    end

    NATS.publish('healthmanager.start')
  end

  def queue_requests?
    @dequeueing_rate != 0
  end
end

if $0 == __FILE__ || File.expand_path($0) == File.expand_path(File.join(File.dirname(__FILE__), '../bin/health_manager'))

  config_path = ENV["CLOUD_FOUNDRY_CONFIG_PATH"] || File.join(File.dirname(__FILE__), '../config')
  config_file = File.join(config_path, "health_manager.yml")
  options = OptionParser.new do |opts|
    opts.banner = 'Usage: healthmanager [OPTIONS]'
    opts.on("-c", "--config [ARG]", "Configuration File") do |opt|
      config_file = opt
    end
    opts.on("-h", "--help", "Help") do
      puts opts
      exit
    end
  end
  options.parse!(ARGV.dup)

  begin
    config = YAML.load_file(config_file)
  rescue => e
    $stderr.puts "Could not read configuration file:  #{e}"
    exit 1
  end

  EM.epoll

  EM.run { HealthManager.start(config) }
end
