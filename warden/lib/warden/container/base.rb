require "warden/event_emitter"
require "warden/logger"
require "warden/errors"
require "warden/container/spawn"

require "eventmachine"
require "set"
require "shellwords"

module Warden

  module Container

    module State
      class Base
        def self.to_s
          self.name.split("::").last.downcase
        end
      end

      # Container object created, but setup not performed
      class Born < Base; end

      # Container setup completed
      class Active < Base; end

      # Triggered by an error condition in the container (e.g. OOM) or
      # explicitly by the user. All processes have been killed but the
      # container exists for introspection. No new commands may be run.
      class Stopped < Base; end

      # All state associated with the container has been destroyed.
      class Destroyed < Base; end
    end

    class Base

      include EventEmitter
      include Spawn
      include Logger

      class << self

        # Stores a map of handles to their respective container objects. Only
        # live containers are reachable through this map. Containers are only
        # added when they are succesfully started, and are immediately removed
        # when they are being destroyed.
        def registry
          @registry ||= {}
        end

        def reset!
          @registry = nil
        end

        # This needs to be set by some setup routine. Container logic expects
        # this attribute to hold an instance of Warden::Pool::NetworkPool.
        attr_accessor :network_pool

        # Acquire resources required for every container instance.
        def acquire(resources)
          unless resources[:network]
            network = network_pool.acquire
            unless network
              raise WardenError.new("could not acquire network")
            end

            resources[:network] = network
          end
        end

        # Release resources required for every container instance.
        def release(resources)
          if network = resources.delete(:network)
            network_pool.release(network)
          end
        end

        # Override #new to make sure that acquired resources are released when
        # one of the pooled resourced can not be required. Acquiring the
        # necessary resources must be atomic to prevent leakage.
        def new(conn, options = {})
          resources = {}
          acquire(resources)
          instance = super(resources, options)
          instance.register_connection(conn)
          instance

        rescue WardenError
          release(resources)
          raise
        end

        # Called before the server starts.
        def setup(config = {})
          # noop
        end

        # Generates process-wide unique job IDs
        def generate_job_id
          @job_id ||= 0
          @job_id += 1
        end

        # Root path for container assets
        def root_path
          @root_path ||= File.join(Server.container_root, self.name.split("::").last.downcase)
        end
      end

      attr_reader :resources
      attr_reader :connections
      attr_reader :jobs
      attr_reader :events
      attr_reader :limits

      def initialize(resources, options = {})
        @resources   = resources
        @connections = ::Set.new
        @jobs        = {}
        @state       = State::Born
        @events      = Set.new
        @limits      = {}
        @options     = options

        on(:before_create) {
          check_state_in(State::Born)

          self.state = State::Active
        }

        on(:after_create) {
          # Clients should be able to look this container up
          self.class.registry[handle] = self
        }

        on(:before_stop) {
          check_state_in(State::Active)

          self.state = State::Stopped
        }

        on(:after_stop) {
          # Here for symmetry
        }

        on(:before_destroy) {
          check_state_in(State::Active, State::Stopped)

          # Clients should no longer be able to look this container up
          self.class.registry.delete(handle)

          unless self.state == State::Stopped
            begin
              self.stop

            rescue WardenError
              # Ignore, stopping before destroy is a best effort
            end
          end

          self.state = State::Destroyed
        }

        on(:after_destroy) {
          # Here for symmetry
        }

        on(:finalize) {
          # Release all resources after the container has been destroyed and
          # the after_destroy have executed.
          self.class.release(resources)
        }
      end

      def network
        @network ||= resources[:network]
      end

      def handle
        @handle ||= network.to_hex
      end

      def gateway_ip
        @gateway_ip ||= network + 1
      end

      def container_ip
        @container_ip ||= network + 2
      end

      def grace_time
        @options[:grace_time] || Server.container_grace_time
      end

      def cancel_grace_timer
        return unless @destroy_timer

        debug "grace timer: cancel"

        ::EM.cancel_timer(@destroy_timer)
        @destroy_timer = nil
      end

      def setup_grace_timer
        debug "grace timer: setup (%.3fs)" % grace_time

        @destroy_timer = ::EM.add_timer(grace_time) do
          debug "grace timer: fired"
          fire_grace_timer
        end
      end

      def fire_grace_timer
        f = Fiber.new do
          debug "grace timer: destroy"

          begin
            destroy

          rescue WardenError => err
            # Ignore, destroying after grace time is a best effort
          end
        end

        f.resume
      end

      def register_connection(conn)
        cancel_grace_timer

        if connections.add?(conn)
          conn.on(:close) do
            connections.delete(conn)

            # Setup grace timer when this was the last connection to reference
            # this container, and it hasn't already been destroyed
            if connections.empty? && !has_state?(State::Destroyed)
              setup_grace_timer
            end
          end
        end
      end

      def root_path
        @root_path ||= self.class.root_path
      end

      def container_path
        @container_path ||= File.join(root_path, "instances", handle)
      end

      def create(config={})
        debug "entry"

        begin
          emit(:before_create)
          do_create(config)
          emit(:after_create)

          handle

        rescue WardenError
          begin
            destroy

          rescue WardenError
            # Ignore, raise original error
          end

          raise
        end

      rescue => err
        warn "error: #{err.message}"
        raise

      ensure
        debug "exit"
      end

      def do_create
        raise WardenError.new("not implemented")
      end

      def stop
        debug "entry"

        emit(:before_stop)
        do_stop
        emit(:after_stop)

        "ok"

      rescue => err
        warn "error: #{err.message}"
        raise

      ensure
        debug "exit"
      end

      def do_stop
        raise WardenError.new("not implemented")
      end

      def destroy
        debug "entry"

        emit(:before_destroy)
        do_destroy
        emit(:after_destroy)

        # Trigger separate "finalize" event so hooks in "after_destroy" still
        # have access to the allocated resources (e.g. the container's handle
        # via the network allocation)
        emit(:finalize)

        "ok"

      rescue => err
        warn "error: #{err.message}"
        raise

      ensure
        debug "exit"
      end

      def do_destroy
        raise WardenError.new("not implemented")
      end

      def spawn(script)
        debug "entry"

        check_state_in(State::Active)

        job = create_job(script)
        jobs[job.job_id.to_s] = job

        # Return job id to caller
        job.job_id

      rescue => err
        warn "error: #{err.message}"
        raise

      ensure
        debug "exit"
      end

      def link(job_id)
        debug "entry"

        job = jobs[job_id.to_s]
        unless job
          raise WardenError.new("no such job")
        end

        job.yield

      rescue => err
        warn "error: #{err.message}"
        raise

      ensure
        debug "exit"
      end

      def run(script)
        debug "entry"

        link(spawn(script))

      rescue => err
        warn "error: #{err.message}"
        raise

      ensure
        debug "exit"
      end

      def net_in
        debug "entry"

        check_state_in(State::Active)

        do_net_in

      rescue => err
        warn "error: #{err.message}"
        raise

      ensure
        debug "exit"
      end

      def net_out(spec)
        debug "entry"

        check_state_in(State::Active)

        do_net_out(spec)

      rescue => err
        warn "error: #{err.message}"
        raise

      ensure
        debug "exit"
      end

      def copy(direction, src_path, dst_path, owner=nil)
        debug "entry"

        check_state_in(State::Active)

        if owner && (direction == "in")
          raise WardenError.new("You can only supply a target owner when copying out")
        end

        src_path = Shellwords.shellescape(src_path)
        dst_path = Shellwords.shellescape(dst_path)

        if direction == "in"
          do_copy_in(src_path, dst_path)
        else
          chown_opts = Shellwords.shellescape(owner) if owner
          do_copy_out(src_path, dst_path, owner)
        end

      ensure
        debug "exit"
      end

      def get_limit(limit_name)
        debug "entry"

        check_state_in(State::Active, State::Stopped)

        getter = "get_limit_#{limit_name}"
        if respond_to?(getter)
          self.send(getter)
        else
          raise WardenError.new("Unknown limit #{limit_name}")
        end

      rescue => err
        warn "error: #{err.message}"
        raise

      ensure
        debug "exit"
      end

      def set_limit(limit_name, args)
        debug "entry"

        check_state_in(State::Active)

        setter = "set_limit_#{limit_name}"
        if respond_to?(setter)
          self.send(setter, args)
        else
          raise WardenError.new("Unknown limit #{limit_name}")
        end

      rescue => err
        warn "error: #{err.message}"
        raise

      ensure
        debug "exit"
      end

      def info
        debug "entry"

        check_state_in(State::Active, State::Stopped)

        get_info

      rescue => err
        warn "error: #{err.message}"
        raise

      ensure
        debug "exit"
      end

      def get_info
        { 'state'  => self.state.to_s,
          'events' => self.events.to_a,
          'limits' => self.limits,
          'stats'  => {},
        }
      end

      protected

      def state
        @state
      end

      def state=(state)
        @state = state
      end

      def has_state?(state)
        self.state == state
      end

      def check_state_in(*states)
        unless states.include?(self.state)
          states_str = states.map {|s| s.to_s }.join(', ')
          raise WardenError.new("Container state must be one of '#{states_str}', current state is '#{self.state}'")
        end
      end

      class Job

        include Logger

        attr_reader :container
        attr_reader :job_id

        def initialize(container)
          @container = container
          @job_id = container.class.generate_job_id

          @status = nil
          @yielded = []
        end

        def yield
          return @status if @status
          @yielded << Fiber.current
          Fiber.yield
        end

        def resume(status)
          @status = status
          @yielded.each { |f| f.resume(@status) }
        end
      end
    end
  end
end
