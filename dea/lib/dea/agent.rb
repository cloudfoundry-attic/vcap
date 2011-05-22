# Copyright (c) 2009-2011 VMware, Inc.
$:.unshift(File.join(File.dirname(__FILE__)))

begin
  require 'fiber'
rescue LoadError
  $stderr.puts "DEA requires a Ruby implementation that supports Fibers"
  exit 1
end

require 'fcntl'
require 'logger'
require 'logging'
require 'pp'
require 'set'
require 'socket'
require 'tempfile'
require 'time'
require 'timeout'
require 'yaml'
require 'em-http'
require 'nats/client'
require 'thin'

require 'vcap/common'
require 'vcap/component'

module DEA

  require 'directory'
  require 'secure'

  class NonFatalTimeOutError < StandardError
  end

  class Agent

    VERSION = 0.99

    # Allow modular security models
    include DEA::Secure

    # Some sane app resource defaults
    DEFAULT_APP_MEM     = 512 #512MB
    DEFAULT_APP_DISK    = 256 #256MB
    DEFAULT_APP_NUM_FDS = 1024

    # Max limits for DEA
    DEFAULT_MAX_CLIENTS = 1024

    MONITOR_INTERVAL  = 2    # 2 secs
    MAX_USAGE_SAMPLES = (1*60)/MONITOR_INTERVAL  # 1 minutes @ 5 sec interval
    CRASHES_REAPER_INTERVAL   = 30   # 30 secs
    CRASHES_REAPER_TIMEOUT = 3600 # delete crashes older than 1 hour

    # CPU Thresholds
    BEGIN_RENICE_CPU_THRESHOLD = 50
    MAX_RENICE_VALUE = 20

    VARZ_UPDATE_INTERVAL  = 1    # 1 secs

    APP_STATE_FILE = 'applications.json'

    TAINT_MS_PER_APP = 10
    TAINT_MS_FOR_MEM = 100
    TAINT_MAX_DELAY  = 250

    DEFAULT_EVACUATION_DELAY = 30  # Default time to wait (in secs) for evacuation and restart of apps.

    SECURE_USER = /#{Secure::SECURE_USER_STRING}/

    # How long to wait in between logging the structure of the apps directory in the event that a du takes excessively long
    APPS_DUMP_INTERVAL = 30*60

    def initialize(config)
      @logger = VCAP.create_logger('dea', :log_file => config['log_file'], :log_rotation_interval => config['log_rotation_interval'])
      @logger.level = config['log_level']
      @secure = config['secure']
      @enforce_ulimit = config['enforce_ulimit']

      @droplets = {}
      @usage = {}
      @snapshot_scheduled = false
      @disable_dir_cleanup = config['disable_dir_cleanup']

      @downloads_pending = {}

      @shutting_down = false

      # Path to the ruby executable the dea should use when executing the prepare script.
      # BOSH sets this in the config. For development, try to pick a ruby if none provided.
      @dea_ruby = config['dea_ruby'] || `which ruby`.strip
      verify_ruby(@dea_ruby)

      @runtimes = config['runtimes']

      @local_ip     = VCAP.local_ip(config['local_route'])
      @max_memory   = config['max_memory'] # in MB
      @multi_tenant = config['multi_tenant']
      @max_clients  = @multi_tenant ? DEFAULT_MAX_CLIENTS : 1
      @reserved_mem = 0
      @mem_usage    = 0
      @num_clients  = 0
      @num_cores    = VCAP.num_cores
      @file_viewer_port = config['filer_port']
      @filer_start_attempts = 0   # How many times we've tried to start the filer
      @filer_start_timer = nil    # The periodic timer responsible for starting the filer
      @evacuation_delay = config['evacuation_delay'] || DEFAULT_EVACUATION_DELAY
      @recovered_droplets = false

      # Various directories and files we will use
      @pid_filename   = config['pid']
      @droplet_dir    = config['base_dir']
      @staged_dir     = File.join(@droplet_dir, 'staged')
      @apps_dir       = File.join(@droplet_dir, 'apps')
      @db_dir         = File.join(@droplet_dir, 'db')
      @app_state_file = File.join(@db_dir, APP_STATE_FILE)

      # If a du of the apps dir takes excessively long we log out the directory structure
      # here.
      @last_apps_dump = nil
      if config['log_file']
        @apps_dump_dir = File.dirname(config['log_file'])
      else
        @apps_dump_dir = ENV['TMPDIR'] || '/tmp'
      end

      @nats_uri = config['mbus']
      @heartbeat_interval = config['intervals']['heartbeat']

      # XXX(mjp) - Ugh, this is needed for VCAP::Component.register(). Find a better solution when time permits.
      @config = config.dup()
    end

    def run()
      @logger.info("Starting VCAP DEA (#{VERSION})")
      @logger.info("Pid file: %s" % (@pid_filename))
      begin
        @pid_file = VCAP::PidFile.new(@pid_filename)
      rescue => e
        @logger.fatal("Can't create DEA pid file: #{e}")
        exit 1
      end
      @logger.info("Enabling Secure Mode") if @secure
      setup_secure_mode

      @logger.info("Using ruby @ #{@dea_ruby}")

      Bundler.with_clean_env { setup_runtimes }

      @logger.info("Using network: #{@local_ip}")

      EM.set_descriptor_table_size(16384) # Requires Root privileges
      @logger.info "Socket Limit:#{EM.set_descriptor_table_size}"

      mem = "#{@max_memory}M"
      mem = "#{@max_memory/1024.0}G" if @max_memory > 1024
      @logger.info("Max Memory set to #{mem}")
      @logger.info("Utilizing #{@num_cores} cpu cores")
      @multi_tenant ? @logger.info('Allowing multi-tenancy') : @logger.info('Restricting to single tenant')

      @logger.info("Using directory: #{@droplet_dir}/")

      # Make sure all the correct directories exist.
      begin
        FileUtils.mkdir_p(@droplet_dir)
        FileUtils.mkdir_p(@staged_dir)
        FileUtils.mkdir_p(@apps_dir)
        FileUtils.mkdir_p(@db_dir)
        if @secure # Allow traversal by secure users
          FileUtils.chmod(0711, @apps_dir)
          FileUtils.chmod(0711, @droplet_dir)
        end
      rescue => e
        @logger.fatal("Can't create support directories: #{e}")
        exit 1
      end

      begin
        DEA::Agent.ensure_writable(@apps_dump_dir)
      rescue => e
        @logger.fatal("Unable to write to #{@apps_dump_dir}: #{e}")
        exit 1
      end

      # Clean the staged directory on startup
      FileUtils.rm_f(File.join(@staged_dir,'*')) unless @disable_dir_cleanup

      EM.next_tick do
        unless start_file_viewer
          # Periodically try to start the file viewer in case of port contention
          @filer_start_timer = EM.add_periodic_timer(1) do
            if start_file_viewer
              EM.cancel_timer(@filer_start_timer)
              @filer_start_timer = nil
            end
          end
        end
      end

      ['TERM', 'INT', 'QUIT'].each { |s| trap(s) { shutdown() } }
      trap('USR2') { evacuate_apps_then_quit() }

      NATS.on_error do |e|
        @logger.error("EXITING! NATS error: #{e}")
        # Only snapshot app state if we had a chance to recover saved state. This prevents a connect error
        # that occurs before we can recover state from blowing existing data away.
        snapshot_app_state if @recovered_droplets
        exit!
      end

      EM.error_handler do |e|
        @logger.error "Eventmachine problem, #{e}"
        @logger.error("#{e.backtrace.join("\n")}")
      end

      NATS.start(:uri => @nats_uri) do

        # Register ourselves with the system
        VCAP::Component.register(:type => 'DEA', :host => @local_ip, :config => @config, :index => @config['index'])

        uuid = VCAP::Component.uuid

        # Setup our identity
        @hello_message = { :id => uuid, :ip => @local_ip, :port => @file_viewer_port, :version => VERSION }.freeze
        @hello_message_json = @hello_message.to_json

        # Setup our listeners..
        NATS.subscribe('dea.status') { |msg, reply| process_dea_status(msg, reply) }
        NATS.subscribe('droplet.status') { |msg, reply| process_droplet_status(msg, reply) }
        NATS.subscribe('dea.discover') { |msg, reply| process_dea_discover(msg, reply) }
        NATS.subscribe('dea.find.droplet') { |msg, reply| process_dea_find_droplet(msg, reply) }
        NATS.subscribe('dea.update') { |msg| process_dea_update(msg) }
        NATS.subscribe('dea.stop') { |msg| process_dea_stop(msg) }
        NATS.subscribe("dea.#{uuid}.start") { |msg| process_dea_start(msg) }
        NATS.subscribe('router.start') {  |msg| process_router_start(msg) }
        NATS.subscribe('healthmanager.start') { |msg| process_healthmanager_start(msg) }

        # Recover existing application state.
        recover_existing_droplets
        delete_untracked_instance_dirs

        EM.add_periodic_timer(@heartbeat_interval) { send_heartbeat }
        EM.add_timer(MONITOR_INTERVAL) { monitor_apps }
        EM.add_periodic_timer(CRASHES_REAPER_INTERVAL) { crashes_reaper }
        EM.add_periodic_timer(VARZ_UPDATE_INTERVAL) { snapshot_varz }

        NATS.publish('dea.start', @hello_message_json)
      end
    end

    def send_heartbeat
      return if @droplets.empty? || @shutting_down
      heartbeat = {:droplets => []}
      @droplets.each_value do |instances|
        instances.each_value do |instance|
          heartbeat[:droplets] << generate_heartbeat(instance)
        end
      end
      NATS.publish('dea.heartbeat', heartbeat.to_json)
    end

    def send_single_heartbeat(instance)
      heartbeat = {:droplets => [generate_heartbeat(instance)]}
      NATS.publish('dea.heartbeat', heartbeat.to_json)
    end

    def generate_heartbeat(instance)
      {
        :droplet => instance[:droplet_id],
        :version => instance[:version],
        :instance => instance[:instance_id],
        :index => instance[:instance_index],
        :state => instance[:state],
        :state_timestamp => instance[:state_timestamp]
      }
    end

    def process_droplet_status(message, reply)
      return if @shutting_down
      message_json = JSON.parse(message)
      @droplets.each_value do |instances|
        instances.each_value do |instance|
          next unless [:STARTING,:RUNNING].include?(instance[:state])
          response = {
            :name => instance[:name],
            :host => @local_ip,
            :port => instance[:port],
            :uris => instance[:uris],
            :uptime => Time.now - instance[:start],
            :mem_quota => instance[:mem_quota],
            :disk_quota => instance[:disk_quota],
            :fds_quota => instance[:fds_quota]
          }
          response[:usage] = @usage[instance[:pid]].last if @usage[instance[:pid]]
          NATS.publish(reply, response.to_json)
        end
      end
    end

    def snapshot_varz
      VCAP::Component.varz[:apps_max_memory] = @max_memory
      VCAP::Component.varz[:apps_reserved_memory] = @reserved_mem
      VCAP::Component.varz[:apps_used_memory] = (@mem_usage / 1024).to_i # based in K, translate to MB
      VCAP::Component.varz[:num_apps] = @num_clients
      VCAP::Component.varz[:state] = :SHUTTING_DOWN if @shutting_down
    end

    def process_dea_status(message, reply)
      message_json = JSON.parse(message)
      @logger.debug("DEA received status message")

      # Respond with our status information here, start with hello string.
      response = @hello_message.dup
      response[:max_memory] = @max_memory
      response[:reserved_memory] = @reserved_mem
      response[:used_memory] = @mem_usage / 1024.0 # based in K, translate to MB
      response[:num_clients] = @num_clients
      response[:state] = :SHUTTING_DOWN if @shutting_down

      # We should send some data here to help describe ourselves.
      NATS.publish(reply, response.to_json)
    end

    def process_dea_discover(message, reply)
      return if @shutting_down
      @logger.debug("DEA received discovery message: #{message}")
      message_json = JSON.parse(message)
      # Respond with where to find us if we can help.
      if @shutting_down
        @logger.debug('Ignoring request, shutting down.')
      elsif @num_clients >= @max_clients || @reserved_mem > @max_memory
        @logger.debug('Ignoring request, not enough resources.')
      else
        # Check that we properly support the runtime requested
        unless runtime_supported? message_json['runtime']
          @logger.debug("Ignoring request, #{message_json['runtime']} runtime not supported.")
          return
        end

        # Pull resource limits and make sure we can accomodate
        limits = message_json['limits']
        mem_needed = limits['mem']
        droplet_id = message_json['droplet'].to_i
        if (@reserved_mem + mem_needed > @max_memory)
          @logger.debug('Ignoring request, not enough resources.')
          return
        end
        delay = calculate_help_taint(droplet_id)
        delay = ([delay, TAINT_MAX_DELAY].min)/1000.0
        EM.add_timer(delay) { NATS.publish(reply, @hello_message_json) }
      end
    end

    def calculate_help_taint(droplet_id)
      # Calculate taint based on droplet already running here, then memory and cpu usage, etc.
      taint_ms = 0
      already_running = @droplets[droplet_id]
      taint_ms += (already_running.size * TAINT_MS_PER_APP) if already_running
      mem_percent = @reserved_mem / @max_memory.to_f
      taint_ms += (mem_percent * TAINT_MS_FOR_MEM)
      # TODO, add in CPU as a component..
      taint_ms
    end

    def process_dea_find_droplet(message, reply)
      return if @shutting_down
      message_json = JSON.parse(message)
      @logger.debug("DEA received find droplet message: #{message}")

      droplet_id = message_json['droplet']
      version = message_json['version']
      instance_ids = message_json['instances'] ? Set.new(message_json['instances']) : nil
      indices = message_json['indices'] ? Set.new(message_json['indices']) : nil
      states = message_json['states'] ? Set.new(message_json['states']) : nil
      include_stats = message_json['include_stats'] ? message_json['include_stats'] : false

      droplet = @droplets[droplet_id]
      if droplet
        droplet.each_value do |instance|
          version_matched = version.nil? || instance[:version] == version
          instance_matched = instance_ids.nil? || instance_ids.include?(instance[:instance_id])
          index_matched = indices.nil? || indices.include?(instance[:instance_index])
          state_matched = states.nil? || states.include?(instance[:state].to_s)

          if version_matched && instance_matched && index_matched && state_matched
            response = {
              :dea => VCAP::Component.uuid,
              :version => instance[:version],
              :droplet => instance[:droplet_id],
              :instance => instance[:instance_id],
              :index => instance[:instance_index],
              :state => instance[:state],
              :state_timestamp => instance[:state_timestamp],
              :file_uri => "http://#{@local_ip}:#{@file_viewer_port}/droplets/",
              :credentials => @file_auth,
              :staged => instance[:staged]
            }
            if include_stats && instance[:state] == :RUNNING
              response[:stats] = {
                :name => instance[:name],
                :host => @local_ip,
                :port => instance[:port],
                :uris => instance[:uris],
                :uptime => Time.now - instance[:start],
                :mem_quota => instance[:mem_quota],
                :disk_quota => instance[:disk_quota],
                :fds_quota => instance[:fds_quota],
                :cores => @num_cores
              }
              response[:stats][:usage] = @usage[instance[:pid]].last if @usage[instance[:pid]]
            end
            NATS.publish(reply, response.to_json)
          end
        end
      end
    end

    def process_dea_update(message)
      return if @shutting_down
      message_json = JSON.parse(message)
      @logger.debug("DEA received update message: #{message}")
      return unless message_json

      droplet_id = message_json['droplet']
      droplet = @droplets[droplet_id]

      if droplet
        uris = message_json['uris']
        droplet.each_value do |instance|
          current_uris = instance[:uris]

          @logger.debug("Mapping new URIs.")
          @logger.debug("New: #{uris.pretty_inspect} Current: #{current_uris.pretty_inspect}")

          register_instance_with_router(instance, :uris => (uris - current_uris))
          unregister_instance_from_router(instance, :uris => (current_uris - uris))

          instance[:uris] = uris
        end
      end
    end

    def process_dea_stop(message)
      return if @shutting_down
      message_json = JSON.parse(message)
      @logger.debug("DEA received stop message: #{message}")

      droplet_id   = message_json['droplet']
      version      = message_json['version']
      instance_ids = message_json['instances'] ? Set.new(message_json['instances']) : nil
      indices      = message_json['indices'] ? Set.new(message_json['indices']) : nil
      states       = message_json['states'] ? Set.new(message_json['states']) : nil

      return unless instances = @droplets[droplet_id]
      instances.each_value do |instance|
        version_matched  = version.nil? || instance[:version] == version
        instance_matched = instance_ids.nil? || instance_ids.include?(instance[:instance_id])
        index_matched    = indices.nil? || indices.include?(instance[:instance_index])
        state_matched    = states.nil? || states.include?(instance[:state].to_s)
        if (version_matched && instance_matched && index_matched && state_matched)
          instance[:exit_reason] = :STOPPED if [:STARTING, :RUNNING].include?(instance[:state])
          if instance[:state] == :CRASHED
            instance[:state] = :DELETED
            instance[:stop_processed] = false
          end
          stop_droplet(instance)
        end
      end
    end

    def process_dea_start(message)
      return if @shutting_down
      message_json = JSON.parse(message)
      @logger.debug("DEA received start message: #{message}")

      instance_id = VCAP.fast_uuid

      droplet_id = message_json['droplet']
      instance_index = message_json['index']
      services = message_json['services']
      version = message_json['version']
      bits_file = message_json['executableFile']
      bits_uri = message_json['executableUri']
      name = message_json['name']
      uris = message_json['uris']
      sha1 = message_json['sha1']
      app_env = message_json['env']
      users = message_json['users']
      runtime = message_json['runtime']
      framework = message_json['framework']

      # Limits processing
      mem     = DEFAULT_APP_MEM
      num_fds = DEFAULT_APP_NUM_FDS
      disk    = DEFAULT_APP_DISK

      if limits = message_json['limits']
        mem = limits['mem'] if limits['mem']
        num_fds = limits['fds'] if limits['fds']
        disk = limits['disk'] if limits['disk']
      end

      @logger.debug("Requested Limits: mem=#{mem}M, fds=#{num_fds}, disk=#{disk}M")

      if @shutting_down
        @logger.info('Shutting down, ignoring start request')
        return
      elsif @reserved_mem + mem > @max_memory || @num_clients >= @max_clients
        @logger.info('Do not have room for this client application')
        return
      end

      if (!sha1 || !bits_file || !bits_uri)
        @logger.warn("Start request missing proper download information, ignoring request. (#{message})")
        return
      end

      # Check that we properly support the runtime requested
      return unless runtime_supported? runtime

      tgz_file = File.join(@staged_dir, "#{sha1}.tgz")
      instance_dir = File.join(@apps_dir, "#{name}-#{instance_index}-#{instance_id}")

      instance = {
        :droplet_id => droplet_id,
        :instance_id => instance_id,
        :instance_index => instance_index,
        :name => name,
        :dir => instance_dir,
        :uris => uris,
        :users => users,
        :version => version,
        :mem_quota => mem * (1024*1024),
        :disk_quota => disk  * (1024*1024),
        :fds_quota => num_fds,
        :state => :STARTING,
        :runtime => runtime,
        :framework => framework,
        :start => Time.now,
        :state_timestamp => Time.now.to_i,
        :log_id => "(name=%s app_id=%s instance=%s index=%s)" % [name, droplet_id, instance_id, instance_index],
      }

      instances = @droplets[droplet_id] || {}
      instances[instance_id] = instance
      @droplets[droplet_id] = instances

      # Ensure directories are locked down if secure mode is on
      if @secure
        # First grab a user that we will have the application run as..
        user = grab_secure_user
        user[:available] = false
        instance[:secure_user] = user[:user]
      end

      start_operation = proc do
        port = VCAP.grab_ephemeral_port

        @logger.debug('Completed download')
        @logger.info("Starting up instance #{instance[:log_id]} on port:#{port}")

        @logger.debug("Clients: #{@num_clients}")
        @logger.debug("Reserved Memory Usage: #{@reserved_mem} MB of #{@max_memory} MB TOTAL")

        instance[:port] = port

        manifest_file = File.join(instance[:dir], 'droplet.yaml')
        manifest = {}
        manifest = File.open(manifest_file) { |f| YAML.load(f) } if File.file?(manifest_file)

        prepare_script = File.join(instance_dir, 'prepare')
        # once EM allows proper close_on_exec we can remove
        FileUtils.cp(File.expand_path("../../../bin/close_fds", __FILE__), prepare_script)
        FileUtils.chmod(0700, prepare_script)

        # Secure mode requires a platform-specific shell command.
        if @secure
          case RUBY_PLATFORM
          when /linux/
            sh_command = "env -i su -s /bin/sh #{user[:user]}"
          when /darwin/
            sh_command = "env -i su -m #{user[:user]}"
          else
            @logger.fatal("Unsupported platform for secure mode: #{RUBY_PLATFORM}")
            exit 1
          end
        else
          # In non-secure mode, we simply use 'sh' to execute commands, but still strip the environment
          sh_command = "env -i /bin/sh"
        end

        if @secure
          system("chown -R #{user[:user]} #{instance_dir}")
          system("chgrp -R #{DEFAULT_SECURE_GROUP} #{instance_dir}")
          system("chmod -R o-rwx #{instance_dir}")
          system("chmod -R g-rwx #{instance_dir}")
        end

        app_env = setup_instance_env(instance, app_env, services)

        # Add a bit of overhead here for JVM semantics where request is for heap, not total process.
        mem_kbytes = ((mem * 1024) * 1.125).to_i

        # 512 byte blocks
        one_gb = 1024*1024*2
        disk_limit = ((disk*1024)*2)*2
        disk_limit = one_gb if disk_limit > one_gb

        exec_operation = proc do |process|
          process.send_data("cd #{instance_dir}\n")
          if @secure || @enforce_ulimit
            process.send_data("ulimit -m #{mem_kbytes} 2> /dev/null\n")  # ulimit -m takes kb, soft enforce
            process.send_data("ulimit -v 3000000 2> /dev/null\n") # virtual memory at 3G, this will be enforced
            process.send_data("ulimit -n #{num_fds} 2> /dev/null\n")
            process.send_data("ulimit -u 512 2> /dev/null\n") # processes/threads
            process.send_data("ulimit -f #{disk_limit} 2> /dev/null\n") # File size to complete disk usage
            process.send_data("umask 077\n")
          end
          app_env.each { |env| process.send_data("export #{env}\n") }
          process.send_data("#{@dea_ruby} ./prepare true ./startup -p #{port}\n")
          process.send_data("exit\n")
        end

        exit_operation = proc do |_, status|
          @logger.info("#{name} completed running with status = #{status}.")
          @logger.info("#{name} uptime was #{Time.now - instance[:start]}.")
          stop_droplet(instance)
        end

        # Being a bit paranoid here and wipe all processes for the secure user
        # before we start..
        kill_all_procs_for_user(user) if @secure

        Bundler.with_clean_env { EM.system(sh_command, exec_operation, exit_operation) }

        instance[:staged] = instance_dir.sub("#{@apps_dir}/", '')

        # Send the start message, which will bind the router, when we have established the
        # connection..
        detect_app_ready(instance, manifest) do |detected|
          if detected and not instance[:stop_processed]
            @logger.info("Instance #{instance[:log_id]} is ready for connections, notifying system of status")
            instance[:state] = :RUNNING
            instance[:state_timestamp] = Time.now.to_i
            send_single_heartbeat(instance)
            register_instance_with_router(instance)
            schedule_snapshot
          else
            @logger.warn('Giving up on connecting app.')
            stop_droplet(instance)
          end
        end

        detect_app_pid(instance_dir) do |pid|
          if pid and not instance[:stop_processed]
            @logger.info("PID:#{pid} assigned to droplet instance: #{instance[:log_id]}")
            instance[:pid] = pid
            schedule_snapshot
          end
        end
      end

      # Accounting is done here so we do not run ahead with the defers.
      add_instance_resources(instance)

      @logger.debug("reserved_mem = #{@reserved_mem} MB, max_memory = #{@max_memory} MB")

      # Stage and start the droplet instance.
      f = Fiber.new do
        stage_app_dir(bits_file, bits_uri, sha1, tgz_file, instance_dir, runtime)
        start_operation.call
      end
      f.resume

    end

    def process_router_start(message)
      return if @shutting_down
      @logger.debug("DEA received router start message: #{message}")
      @droplets.each_value do |instances|
        instances.each_value do |instance|
          register_instance_with_router(instance) if instance[:state] == :RUNNING
        end
      end
    end

    def process_healthmanager_start(message)
      return if @shutting_down
      @logger.debug("DEA received healthmanager start message: #{message}")
      send_heartbeat
    end

    def schedule_snapshot
      return if @snapshot_scheduled
      @snapshot_scheduled = true
      EM.next_tick { snapshot_app_state }
    end

    def snapshot_app_state
      start = Time.now
      tmp = File.new("#{@db_dir}/snap_#{Time.now.to_i}", 'w')
      tmp.puts(JSON.pretty_generate(@droplets))
      tmp.close
      FileUtils.mv(tmp.path, @app_state_file)
      @logger.debug("Took #{Time.now - start} to snapshot application state.")
      @snapshot_scheduled = false
    end

    def recover_existing_droplets
      unless File.exists?(@app_state_file)
        @recovered_droplets = true
        return
      end
      recovered = nil
      File.open(@app_state_file, 'r') { |f| recovered = Yajl::Parser.parse(f) }
      # Whip through and reconstruct droplet_ids and instance symbols correctly for droplets, state, etc..
      recovered.each_pair do |app_id, instances|
        @droplets[app_id.to_i] = instances
        instances.each_pair do |instance_id, instance|
          new_instance = {}
          instance.each_pair do |key, value|
            new_instance[key.to_sym] = value
          end
          instances[instance_id] = new_instance
          instance = new_instance
          instance[:state] = instance[:state].to_sym if instance[:state]
          instance[:exit_reason] = instance[:exit_reason].to_sym if instance[:exit_reason]
          instance[:orphaned] = true
          instance[:start] = Time.parse(instance[:start]) if instance[:start]

          # Assume they are running until we know different..
          # Accounting is done here so we do not run ahead with the defers.
          instance[:resources_tracked] = false
          add_instance_resources(instance)

          # Don't assume stop has been processed on a recover.
          instance[:stop_processed] = false

          # Account for secure users here as well..
          if @secure && instance[:secure_user]
            user = find_secure_user(instance[:secure_user])
            user[:available] = false
          end
        end
      end
      @recovered_droplets = true

      @logger.info("DEA recovered #{@num_clients} applications") if @num_clients > 0

      # Go ahead and do a monitoring pass here to detect app state
      monitor_apps(true)
      send_heartbeat
      schedule_snapshot
    end

    # Removes any instance dirs without a corresponding instance entry in @droplets
    # NB: This is run once at startup, so not using EM.system to perform the rm is fine.
    def delete_untracked_instance_dirs
      tracked_instance_dirs = Set.new
      for droplet_id, instances in @droplets
        for instance_id, instance in instances
          tracked_instance_dirs << instance[:dir]
        end
      end

      all_instance_dirs = Set.new(Dir.glob(File.join(@apps_dir, '*')))
      to_remove = all_instance_dirs - tracked_instance_dirs
      for dir in to_remove
        @logger.warn("Removing instance dir '#{dir}', doesn't correspond to any instance entry.")
        FileUtils.rm_rf(dir)
      end
    end

    def add_instance_resources(instance)
      return if instance[:resources_tracked]
      instance[:resources_tracked] = true
      @reserved_mem += instance_mem_usage_in_mb(instance)
      @num_clients += 1
    end

    def remove_instance_resources(instance)
      return unless instance[:resources_tracked]
      instance[:resources_tracked] = false
      @reserved_mem -= instance_mem_usage_in_mb(instance)
      @num_clients -= 1
    end

    def instance_mem_usage_in_mb(instance)
      (instance[:mem_quota] / (1024*1024)).to_i
    end

    def grab_ephemeral_port
      socket = TCPServer.new('0.0.0.0', 0)
      socket.setsockopt(Socket::SOL_SOCKET, Socket::SO_REUSEADDR, true)
      Socket.do_not_reverse_lookup = true
      port = socket.addr[1]
      socket.close
      return port
    end

    def detect_app_ready(instance, manifest, &block)
      state_file = manifest['state_file']
      if state_file
        state_file = File.join(instance[:dir], state_file)
        detect_state_ready(instance, state_file, &block)
      else
        detect_port_ready(instance, &block)
      end
    end

    def detect_state_ready(instance, state_file, &block)
      attempts = 0
      timer = EM.add_periodic_timer(0.5) do
        state = nil
        begin
          if File.file?(state_file)
            state = File.open(state_file) { |f| JSON.parse(f.read) }
          end
        rescue
        end
        if state && state['state'] == 'RUNNING'
          block.call(true)
          timer.cancel
        else
          attempts += 1
          if attempts > 600 || instance[:state] != :STARTING # 5 minutes or instance was stopped
            block.call(false)
            timer.cancel
          end
        end
      end
    end

    def detect_port_ready(instance, &block)
      port = instance[:port]
      attempts = 0
      timer = EM.add_periodic_timer(0.5) do
        begin
          # SystemTimer does not work correctly here, possible bad interaction with EM, hence the use of standard Timeout
          Timeout::timeout(0.25, NonFatalTimeOutError) do
            sock = TCPSocket.new(@local_ip, port)
            sock.close
            timer.cancel
            block.call(true)
          end
        rescue => e
          attempts += 1
          if attempts > 120 || instance[:state] != :STARTING # 1 minute or instance was stopped
            timer.cancel
            block.call(false)
          end
        end
      end
    end

    def download_app_bits(bits_uri, sha1, tgz_file)
      f = Fiber.current
      @downloads_pending[sha1] = []
      http = EventMachine::HttpRequest.new(bits_uri).get

      # Use a tmp file here so other queue up and fail the File.exists?
      pending_tgz_file = File.join(@staged_dir, "#{sha1}.pending")

      file = File.open(pending_tgz_file, 'w')
      http.errback {
        @logger.warn("Failed to download app bits from #{bits_uri}")
        file.close
        FileUtils.rm_rf(pending_tgz_file)
        f.resume
      }
      http.stream { |chunk|
        file.write(chunk)
      }
      http.callback {
        file.close
        FileUtils.mv(pending_tgz_file, tgz_file)
        f.resume
      }
      Fiber.yield

    ensure
      # Make sure we release any pending
      pending = @downloads_pending[sha1]
      @downloads_pending.delete(sha1)
      unless pending.nil? || pending.empty?
        pending.each { |f| f.resume }
      end
    end

    # Be conservative here..
    def bind_local_runtime(instance_dir, runtime_name)
      return unless instance_dir && runtime_name && runtime_supported?(runtime_name)
      runtime = @runtimes[runtime_name]

      startup = File.expand_path(File.join(instance_dir, 'startup'))
      return unless File.exists? startup

      startup_contents = File.read(startup)
      new_startup = startup_contents.gsub!('%VCAP_LOCAL_RUNTIME%', runtime['executable'])
      return unless new_startup

      FileUtils.chmod(0600, startup)
      File.open(startup, 'w') { |f| f.write(new_startup) }
      FileUtils.chmod(0500, startup)
    end

    def stage_app_dir(bits_file, bits_uri, sha1, tgz_file, instance_dir, runtime)
      # See if we have bits first..
      # What we do here, in order of preference..
      # 1. Check our own staged directory.
      # 2. Check shared directory from CloudController that could be mounted (bits_file)
      # 3. Pull from http if needed.
      unless File.exist?(tgz_file)

        # If we have a shared volume from the CloudController we can see the bits
        # directly, just link into our staged version.
        if File.exist?(bits_file)
          @logger.debug("Sharing cloud controller's staging directories")
          start = Time.now
          FileUtils.cp(bits_file, tgz_file)
          @logger.debug("Took #{Time.now - start} to copy from shared directory")
        else
          start = Time.now
          @logger.debug("Need to download app bits from #{bits_uri}")

          # We need to download the bits here, so we need to make sure everyone
          # else looking for same bits gets in line..
          if pending = @downloads_pending[sha1]
            @logger.debug("Waiting on another download already in progress")
            pending << Fiber.current
            Fiber.yield
          else
            download_app_bits(bits_uri, sha1, tgz_file)
          end
          download_end = Time.now
          @logger.debug("Took #{download_end - start} to download and write file")
        end
      else
        @logger.debug('Bits already cached locally.')
      end

      start = Time.now

      # Explode the app into its directory and optionally bind its
      # local runtime.
      `mkdir #{instance_dir}; cd #{instance_dir}; tar -xzf #{tgz_file}`
      @logger.warn("Problems staging file #{tgz_file}") if $? != 0

      # Removed the staged bits
      FileUtils.rm_f(tgz_file) unless @disable_dir_cleanup

      bind_local_runtime(instance_dir, runtime)

      @logger.debug("Took #{Time.now - start} to stage the app directory")
    end

    # The format used by VCAP_SERVICES
    def create_services_for_env(services=[])
      whitelist = ['name', 'label', 'plan', 'tags', 'plan_option', 'credentials']
      svcs_hash = {}
      services.each do |svc|
        svcs_hash[svc['label']] ||= []
        svc_hash = {}
        whitelist.each {|k| svc_hash[k] = svc[k] if svc[k]}
        svcs_hash[svc['label']] << svc_hash
      end
      svcs_hash.to_json
    end

    # The format used by VMC_SERVICES
    def create_legacy_services_for_env(services=[])
      whitelist = ['name', 'type', 'vendor', 'version']
      as_legacy = services.map do |svc|
        leg_svc = {}
        whitelist.each {|k| leg_svc[k] = svc[k] if svc[k]}
        leg_svc['tier'] = svc['plan']
        leg_svc['options'] = svc['credentials']
        leg_svc
      end
      as_legacy.to_json
    end

    # The format used by VCAP_APP_INSTANCE
    def create_instance_for_env(instance)
      whitelist = [:instance_id, :instance_index, :name, :uris, :users, :version, :start, :runtime, :state_timestamp, :port]
      env_hash = {}
      whitelist.each {|k| env_hash[k] = instance[k] if instance[k]}
      env_hash[:limits] = {
        :fds  => instance[:fds_quota],
        :mem  => instance[:mem_quota],
        :disk => instance[:disk_quota],
      }
      env_hash[:host] = @local_ip
      env_hash.to_json
    end

    def setup_instance_env(instance, app_env, services)
      env = []

      env << "HOME=#{instance[:dir]}"
      env << "VCAP_APPLICATION='#{create_instance_for_env(instance)}'"
      env << "VCAP_SERVICES='#{create_services_for_env(services)}'"
      env << "VCAP_APP_HOST='#{@local_ip}'"
      env << "VCAP_APP_PORT='#{instance[:port]}'"

      # LEGACY STUFF
      env << "VMC_WARNING_WARNING='All VMC_* environment variables are deprecated, please use VCAP_* versions.'"
      env << "VMC_SERVICES='#{create_legacy_services_for_env(services)}'"
      env << "VMC_APP_INSTANCE='#{instance.to_json}'"
      env << "VMC_APP_NAME='#{instance[:name]}'"
      env << "VMC_APP_ID='#{instance[:instance_id]}'"
      env << "VMC_APP_VERSION='#{instance[:version]}'"
      env << "VMC_APP_HOST='#{@local_ip}'"
      env << "VMC_APP_PORT='#{instance[:port]}'"

      services.each do |service|
        hostname = service['credentials']['hostname'] || service['credentials']['host']
        port = service['credentials']['port']
        env << "VMC_#{service['vendor'].upcase}=#{hostname}:#{port}"  if hostname && port
      end

      # Do the runtime environment settings
      runtime_env(instance[:runtime]).each { |re| env << re }

      # User's environment settings
      # Make sure user's env variables are in double quotes.
      if app_env
        app_env.each do |ae|
          k,v = ae.split('=', 2)
          v = "\"#{v}\"" unless v.start_with? "'"
          env << "#{k}=#{v}"
        end
      end

      return env
    end

    def evacuate_apps_then_quit()
      @shutting_down = true
      @logger.info('Evacuating applications..')
      @droplets.each_pair do |id, instances|
        @logger.debug("Evacuating app #{id}")
        instances.each_value do |instance|
          # skip any crashed instances
          next if instance[:state] == :CRASHED
          instance[:exit_reason] = :DEA_EVACUATION
          send_exited_notification(instance)
          instance[:evacuated] = true
        end
      end
      @logger.info("Scheduling shutdown in #{@evacuation_delay} seconds..")
      @evacuation_delay_timer = EM.add_timer(@evacuation_delay) { shutdown() }
      schedule_snapshot
    end

    def shutdown()
      @shutting_down = true
      @logger.info('Shutting down..')
      @droplets.each_pair do |id, instances|
        @logger.debug("Stopping app #{id}")
        instances.each_value do |instance|
          # skip any crashed instances
          instance[:exit_reason] = :DEA_SHUTDOWN unless instance[:state] == :CRASHED
          stop_droplet(instance)
        end
      end

      # Allows messages to get out.
      EM.add_timer(0.25) do
        snapshot_app_state
        @file_viewer_server.stop!
        NATS.stop { EM.stop }
        @logger.info('Bye..')
        @pid_file.unlink()
      end
    end

    def instance_running?(instance)
      return false unless instance && instance[:pid]
      `ps -o rss= -p #{instance[:pid]}`.length > 0
    end

    def stop_droplet(instance)
      # On stop from cloud controller, this can get called twice. Just make sure we are re-entrant..
      return if (instance[:stop_processed])

      # Unplug us from the system immediately, both the routers and health managers.
      send_exited_message(instance)

      @logger.info("Stopping instance #{instance[:log_id]}")

      # grab secure user
      username = instance[:secure_user]

      # if system thinks this process is running, make sure to execute stop script
      if instance[:pid] || [:STARTING, :RUNNING].include?(instance[:state])
        instance[:state] = :STOPPED unless instance[:state] == :CRASHED
        instance[:state_timestamp] = Time.now.to_i
        stop_cmd = File.join(instance[:dir], 'stop')
        stop_cmd = "su -c #{stop_cmd} #{username}" if @secure
        stop_cmd = "#{stop_cmd} 2> dev/null"

        @logger.debug("Executing stop script: '#{stop_cmd}'")
        Bundler.with_clean_env { EM.system(stop_cmd) } unless (RUBY_PLATFORM =~ /darwin/ and @secure)
      end

      # SECURE_MODE ONLY Put the user back in the pool..
      if (username && @secure)
        # Forcibly kill all processes for this user
        user = find_secure_user(username)
        kill_all_procs_for_user(user)
        EM.add_timer(1) { user[:available] = true }
      end

      # Mark that we have processed the stop command.
      instance[:stop_processed] = true

      # Cleanup resource usage and files..
      cleanup_droplet(instance)
    end

    def cleanup_droplet(instance)
      # Drop usage and resource tracking regardless of state
      remove_instance_resources(instance)
      @usage.delete(instance[:pid]) if instance[:pid]
      # clean up the in memory instance and directory only if the instance didn't crash
      unless instance[:state] == :CRASHED
        if droplet = @droplets[instance[:droplet_id]]
          droplet.delete(instance[:instance_id])
          @droplets.delete(instance[:droplet_id]) if droplet.empty?
          schedule_snapshot
        end
        unless @disable_dir_cleanup
          @logger.debug("#{instance[:name]}: Cleaning up dir #{instance[:dir]}")
          EM.system("rm -rf #{instance[:dir]}")
        end
      end
    end

    def register_instance_with_router(instance, options = {})
      return unless (instance and instance[:uris] and not instance[:uris].empty?)
      NATS.publish('router.register', {
                     :dea  => VCAP::Component.uuid,
                     :host => @local_ip,
                     :port => instance[:port],
                     :uris => options[:uris] || instance[:uris],
                     :tags => {:framework => instance[:framework], :runtime => instance[:runtime]}
                   }.to_json)
    end

    def unregister_instance_from_router(instance, options = {})
      return unless (instance and instance[:uris] and not instance[:uris].empty?)
      NATS.publish('router.unregister', {
                     :dea  => VCAP::Component.uuid,
                     :host => @local_ip,
                     :port => instance[:port],
                     :uris => options[:uris] || instance[:uris]
                   }.to_json)
    end

    def send_exited_notification(instance)
      return if instance[:evacuated]
      exit_message = {
        :droplet => instance[:droplet_id],
        :version => instance[:version],
        :instance => instance[:instance_id],
        :index => instance[:instance_index],
        :reason => instance[:exit_reason],
      }
      exit_message[:crash_timestamp] = instance[:state_timestamp] if instance[:state] == :CRASHED
      exit_message = exit_message.to_json
      NATS.publish('droplet.exited', exit_message)
      @logger.debug("Sent droplet.exited #{exit_message}")
    end

    def send_exited_message(instance)
      return if instance[:notified]

      unregister_instance_from_router(instance)

      unless instance[:exit_reason]
        instance[:exit_reason] = :CRASHED
        instance[:state] = :CRASHED
        instance[:state_timestamp] = Time.now.to_i
        instance.delete(:pid) unless instance_running? instance
      end

      send_exited_notification(instance)

      instance[:notified] = true
    end

    def detect_app_pid(dir)
      detect_attempts = 0
      detect_pid_timer = EM.add_periodic_timer(1) do
        pid_file = File.join(dir, 'run.pid')
        if File.exists?(pid_file)
          pid = File.read(pid_file).strip.to_i
          detect_pid_timer.cancel
          yield pid
        else
          detect_attempts += 1
          if detect_attempts > 300 # 5 minutes
            @logger.debug('Giving up detecting stop file')
            detect_pid_timer.cancel
            yield nil
          end
        end
      end
    end

    def no_monitorable_apps?
      return true if @droplets.empty?
      # If we are here we have droplets, but we need to make sure that we have ones we feel are starting or running.
      @droplets.each_value do |instances|
        instances.each_value do |instance|
          return false if [:STARTING, :RUNNING].include?(instance[:state])
        end
      end
      return true
    end

    # This is only called when in secure mode, cur_usage is in kb, quota is in bytes.
    def check_usage(instance, usage, history)
      return unless instance && usage
      # Check Mem
      if (usage[:mem] > (instance[:mem_quota]/1024))
        logger = Logger.new(File.join(instance[:dir], 'logs', 'err.log'))
        logger.fatal("Memory limit of #{(instance[:mem_quota]/1024/1024).to_i}M exceeded.")
        logger.fatal("Actual usage was #{(usage[:mem]/1024).to_i}M, process terminated.")
        logger.close
        stop_droplet(instance)
      end
      # Check Disk
      if (usage[:disk] > instance[:disk_quota])
        logger = Logger.new(File.join(instance[:dir], 'logs', 'err.log'))
        logger.fatal("Disk usage limit of #{(instance[:disk_quota]/1024/1024).to_i}M exceeded.")
        logger.fatal("Actual usage was #{(usage[:disk]/1024/1024).to_i}M, process terminated.")
        logger.close
        stop_droplet(instance)
      end
      # Check CPU
      return unless history
      if usage[:cpu] > BEGIN_RENICE_CPU_THRESHOLD
        nice = (instance[:nice] || 0) + 1
        if nice < MAX_RENICE_VALUE
          instance[:nice] = nice
          @logger.info("Lowering priority on CPU bound process(#{instance[:name]}), new value:#{nice}")
          %x[renice  #{nice} -u #{instance[:secure_user]}]
        end
      end
      # TODO, Check for an attack, or what looks like one, and look at history?
      # pegged_cpus = @num_cores * 100
    end

    FD_INDEX      = 3
    TYPE_INDEX    = 4
    SIZE_INDEX    = 6
    DELETED_INDEX = 9

    def grab_deleted_file_usage(username)
      user = find_secure_user(username)
      return unless @secure && user
      # Disabled for now on MacOS, where uid is set to -1 in secure mode
      uid = user[:uid]
      if uid && uid.to_i >= 0
        files = %x[lsof -nwu #{uid} -s -l].split("\n")
      else
        files = []
      end
      disk = 0
      files.each do |file|
        parts = file.split(/\s+/)
        next unless parts[DELETED_INDEX] && parts[DELETED_INDEX] =~ /deleted/i
        next unless (parts[TYPE_INDEX] =~ /REG/ && parts[FD_INDEX] =~ /\d+[rwu]?/)
        disk += parts[SIZE_INDEX].to_i
      end
      return disk
    end

    PID_INDEX  = 0
    PPID_INDEX = 1
    CPU_INDEX  = 2
    MEM_INDEX  = 3
    USER_INDEX = 4

    def crashes_reaper
      @droplets.each_value do |instances|
        # delete all crashed instances that are older than an hour
        instances.delete_if do |_, instance|
          delete_instance = instance[:state] == :CRASHED && Time.now.to_i - instance[:state_timestamp] > CRASHES_REAPER_TIMEOUT
          if delete_instance
            @logger.debug("Crashes reaper deleted: #{instance[:instance_id]}")
            EM.system("rm -rf #{instance[:dir]}") unless @disable_dir_cleanup
          end
          delete_instance
        end
      end

      @droplets.delete_if do |_, droplet|
        droplet.empty?
      end
    end

    # monitor the running applications
    # NB: We cannot use a periodic timer here because of EM.system. If we did, and the du takes longer than the monitor
    # interval, we could end up with multiple du's running concurrently.
    def monitor_apps(startup_check = false)
      # Always reset
      @mem_usage = 0
      VCAP::Component.varz[:running_apps] = []

      if (no_monitorable_apps? && !startup_check)
        EM.add_timer(MONITOR_INTERVAL) { monitor_apps(false) }
        return
      end

      pid_info = {}
      user_info = {}
      start = Time.now

      # BSD style ps invocation
      ps_start = Time.now
      process_statuses = `ps axo pid=,ppid=,pcpu=,rss=,user=`.split("\n")
      ps_elapsed = Time.now - ps_start
      @logger.warn("Took #{ps_elapsed}s to execute ps. (#{process_statuses.length} entries returned)") if ps_elapsed > 0.25
      process_statuses.each do |process_status|
        parts = process_status.lstrip.split(/\s+/)
        pid = parts[PID_INDEX].to_i
        pid_info[pid] = parts
        (user_info[parts[USER_INDEX]] ||= []) << parts if (@secure && parts[USER_INDEX] =~ SECURE_USER)
      end

      # This really, really needs refactoring, but seems like the least intrusive/failure-prone way
      # of making the du non-blocking in all but the startup case...
      du_start = Time.now
      if startup_check
        du_all_out = `cd #{@apps_dir}; du -sk * 2> /dev/null`
        monitor_apps_helper(startup_check, start, du_start, du_all_out, pid_info, user_info)
      else
        du_proc = proc do |p|
          p.send_data("cd #{@apps_dir}\n")
          p.send_data("du -sk * 2> /dev/null\n")
          p.send_data("exit\n")
        end

        cont_proc = proc do |output, status|
          monitor_apps_helper(startup_check, start, du_start, output, pid_info, user_info)
        end

        EM.system('/bin/sh', du_proc, cont_proc)
      end
    end

    def monitor_apps_helper(startup_check, ma_start, du_start, du_all_out, pid_info, user_info)
      running_apps = []

      # Do disk summary
      du_hash = {}
      du_elapsed = Time.now - du_start
      @logger.warn("Took #{du_elapsed}s to execute du.") if du_elapsed > 0.25
      if (du_elapsed > 10) && (!@last_apps_dump || ((Time.now - @last_apps_dump) > APPS_DUMP_INTERVAL))
        dump_apps_dir
        @last_apps_dump = Time.now
      end

      du_entries = du_all_out.split("\n")
      du_entries.each do |du_entry|
        size, dir = du_entry.split("\t")
        size = size.to_i * 1024 # Convert to bytes
        du_hash[dir] = size
      end

      metrics = {:framework => {}, :runtime => {}}

      @droplets.each_value do |instances|
        instances.each_value do |instance|
          if instance[:pid] && pid_info[instance[:pid]]
            pid = instance[:pid]
            mem = cpu = 0
            disk = du_hash[File.basename(instance[:dir])] || 0
            # For secure mode, gather all stats for secure_user so we can process forks, etc.
            if @secure && user_info[instance[:secure_user]]
              user_info[instance[:secure_user]].each do |part|
                mem += part[MEM_INDEX].to_f
                cpu += part[CPU_INDEX].to_f
                # disabled for now, LSOF is too slow to run per app/user
                # deleted_disk = grab_deleted_file_usage(instance[:secure_user])
                # disk += deleted_disk
              end
            else
              mem = pid_info[pid][MEM_INDEX].to_f
              cpu = pid_info[pid][CPU_INDEX].to_f
            end
            usage = @usage[pid] ||= []
            cur_usage = { :time => Time.now, :cpu => cpu, :mem => mem, :disk => disk }
            usage << cur_usage
            usage.shift if usage.length > MAX_USAGE_SAMPLES
            check_usage(instance, cur_usage, usage) if @secure

            #@logger.debug("Droplet Stats are = #{JSON.pretty_generate(usage)}")
            @mem_usage += mem

            metrics.each do |key, value|
              metric = value[instance[key]] ||= {:used_memory => 0, :reserved_memory => 0,
                                                 :used_disk => 0, :used_cpu => 0}
              metric[:used_memory] += mem
              metric[:reserved_memory] += instance[:mem_quota] / 1024
              metric[:used_disk] += disk
              metric[:used_cpu] += cpu
            end

            # Track running apps for varz tracking
            i2 = instance.dup
            i2[:usage] = cur_usage # Snapshot

            running_apps << i2

            # Re-register with router on startup since these are orphaned and may have been dropped.
            register_instance_with_router(instance) if startup_check
          else
            # App *should* no longer be running if we are here
            instance.delete(:pid)
            # Check to see if this is an orphan that is no longer running, clean up here if needed
            # since there will not be a cleanup proc or stop call associated with the instance..
            stop_droplet(instance) if (instance[:orphaned] && !instance[:stop_processed])
          end
        end
      end
      # export running app information to varz
      VCAP::Component.varz[:running_apps] = running_apps
      VCAP::Component.varz[:frameworks] = metrics[:framework]
      VCAP::Component.varz[:runtimes] = metrics[:runtime]
      ttlog = Time.now - ma_start
      @logger.warn("Took #{ttlog} to process ps and du stats") if ttlog > 0.4
      EM.add_timer(MONITOR_INTERVAL) { monitor_apps(false) } unless startup_check
    end

    # This is for general access to the file system for the staged droplets.
    def start_file_viewer
      success = false
      begin
        apps_dir = @apps_dir
        @file_auth = [VCAP.fast_uuid, VCAP.fast_uuid]
        auth = @file_auth
        @file_viewer_server = Thin::Server.new(@local_ip, @file_viewer_port, :signals => false) do
          Thin::Logging.silent = true
          use Rack::Auth::Basic do |username, password|
            [username, password] == auth
          end
          map '/droplets' do
            run DEA::Directory.new(apps_dir)
          end
        end
        @file_viewer_server.start!
        @logger.info("File service started on port: #{@file_viewer_port}")
        @filer_start_attempts += 1
        success = true
      rescue => e
        @logger.fatal("Filer service failed to start: #{@file_viewer_port} already in use?: #{e}")
        @filer_start_attempts += 1
        if @filer_start_attempts >= 5
          @logger.fatal("Giving up on trying to start filer, exiting...")
          exit 1
        end
      end
      success
    end

    def verify_ruby(path_to_ruby)
      raise "Ruby @ '#{path_to_ruby}' doesn't exist" unless File.exist?(path_to_ruby)
      raise "Ruby @ '#{path_to_ruby}' isn't executable" unless File.executable?(path_to_ruby)
    end

    def runtime_supported?(runtime_name)
      unless runtime_name && runtime = @runtimes[runtime_name]
        @logger.debug("Ignoring request, no suitable runtimes available for '#{runtime_name}'")
        return false
      end
      unless runtime['enabled']
        @logger.debug("Ignoring request, runtime not enabled for '#{runtime_name}'")
        return false
      end
      true
    end

    def runtime_env(runtime_name)
      env = []
      if runtime_name && runtime = @runtimes[runtime_name]
        if re = runtime['environment']
          re.each { |k,v| env << "#{k}=#{v}"}
        end
      end
      env
    end

    # This determines out runtime support.
    def setup_runtimes
      if @runtimes.nil? || @runtimes.empty?
        @logger.fatal("Can't determine application runtimes, exiting")
        exit 1
      end
      @logger.info("Checking runtimes:")

      @runtimes.each do |name, runtime|
        # Only enable when we succeed
        runtime['enabled'] = false
        pname = "#{name}:".ljust(10)

        # Check that we can get a version from the executable
        version_flag = runtime['version_flag'] || '-v'

        expanded_exec = `which #{runtime['executable']}`
        unless $? == 0
          @logger.info("  #{pname} FAILED, executable '#{runtime['executable']}' not found")
          next
        end
        expanded_exec.strip!

        # java prints to stderr, so munch them both..
        version_check = `#{expanded_exec} #{version_flag} 2>&1`.strip!
        unless $? == 0
          @logger.info("  #{pname} FAILED, executable '#{runtime['executable']}' not found")
          next
        end
        runtime['executable'] = expanded_exec

        next unless runtime['version']
        # Check the version for a match
        if /#{runtime['version']}/ =~ version_check
          # Additional checks should return true
          if runtime['additional_checks']
            additional_check = `#{runtime['executable']} #{runtime['additional_checks']} 2>&1`
            unless additional_check =~ /true/i
              @logger.info("  #{pname} FAILED, additional checks failed")
            end
          end
          runtime['enabled'] = true
          @logger.info("  #{pname} OK")
        else
          @logger.info("  #{pname} FAILED, version mismatch (#{version_check})")
        end
      end
    end

    # Logs out the directory structure of the apps dir. This produces both a summary
    # (top level view) of the directory, as well as a detailed view.
    def dump_apps_dir
      now = Time.now
      pid = fork do
        # YYYYMMDD_HHMM
        tsig = "%04d%02d%02d_%02d%02d" % [now.year, now.month, now.day, now.hour, now.min]
        summary_file = File.join(@apps_dump_dir, "apps.du.#{tsig}.summary")
        details_file = File.join(@apps_dump_dir, "apps.du.#{tsig}.details")
        exec("du -skh #{@apps_dir}/* > #{summary_file} 2>&1; du -h --max-depth 6 #{@apps_dir} > #{details_file}")
      end
      Process.detach(pid)
      pid
    end

    def self.ensure_writable(dir)
      test_file = File.join(dir, "dea.#{Process.pid}.sentinel")
      FileUtils.touch(test_file)
      FileUtils.rm_f(test_file)
    end

  end

end
