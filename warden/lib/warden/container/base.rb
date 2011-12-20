require "warden/logger"
require "warden/errors"
require "warden/container/spawn"

require "eventmachine"
require "set"

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

      # Triggered by an error condition in the container (OOM, Quota violation)
      # or explicitly by the user.  All processes have been killed but the
      # container exists for introspection.  No new commands may be run.
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
              # Release network after some time to make sure the kernel has
              # time to clean up things such as lingering connections.
              ::EM.add_timer(5) {
                network_pool.release(network)
              }
          end
        end

        # Override #new to make sure that acquired resources are released when
        # one of the pooled resourced can not be required. Acquiring the
        # necessary resources must be atomic to prevent leakage.
        def new(conn)
          resources = {}
          acquire(resources)
          instance = super(resources)
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
      end

      attr_reader :resources
      attr_reader :connections
      attr_reader :jobs
      attr_reader :events
      attr_reader :limits

      def initialize(resources)
        @resources   = resources
        @connections = ::Set.new
        @jobs        = {}
        @state       = State::Born
        @events      = Set.new
        @limits      = {}

        on(:after_create) {
          # Clients should be able to look this container up
          self.class.registry[handle] = self
        }

        on(:before_destroy) {
          # Clients should no longer be able to look this container up
          self.class.registry.delete(handle)
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

      def register_connection(conn)
        if @destroy_timer
          ::EM.cancel_timer(@destroy_timer)
          @destroy_timer = nil
        end

        if connections.add?(conn)
          conn.on(:close) {
            connections.delete(conn)

            # Destroy container after grace period
            if connections.size == 0
              @destroy_timer =
                ::EM.add_timer(Server.container_grace_time) {
                  f = Fiber.new { destroy }
                  f.resume
                }
            end
          }
        end
      end

      def root_path
        File.join(Server.container_root, self.class.name.split("::").last.downcase)
      end

      def container_path
        File.join(root_path, ".instance-#{handle}")
      end

      def create
        check_state_in(State::Born)

        self.state = State::Active

        emit(:before_create)
        do_create
        emit(:after_create)

        handle
      end

      def do_create
        raise WardenError.new("not implemented")
      end

      def stop
        check_state_in(State::Active)

        self.state = State::Stopped

        emit(:before_stop)
        do_stop
        emit(:after_stop)

        "ok"
      end

      def do_stop
        raise WardenError.new("not implemented")
      end

      def destroy
        check_state_in(State::Active, State::Stopped)

        unless self.state == State::Stopped
          self.stop
        end

        self.state = State::Destroyed

        emit(:before_destroy)
        do_destroy
        emit(:after_destroy)
        emit(:finalize)

        "ok"
      end

      def do_destroy
        raise WardenError.new("not implemented")
      end

      def spawn(script)
        check_state_in(State::Active)

        job = create_job(script)
        jobs[job.job_id.to_s] = job

        # Return job id to caller
        job.job_id
      end

      def link(job_id)
        check_state_in(State::Active, State::Stopped)

        job = jobs[job_id.to_s]
        unless job
          raise WardenError.new("no such job")
        end

        job.yield
      end

      def run(script)
        link(spawn(script))
      end

      def net_in
        check_state_in(State::Active)

        do_net_in
      end

      def net_out(spec)
        check_state_in(State::Active)

        do_net_out(spec)
      end

      def get_limit(limit_name)
        check_state_in(State::Active, State::Stopped)

        getter = "get_limit_#{limit_name}"
        if respond_to?(getter)
          self.send(getter)
        else
          raise WardenError.new("Unknown limit #{limit_name}")
        end
      end

      def set_limit(limit_name, args)
        check_state_in(State::Active)

        setter = "set_limit_#{limit_name}"
        if respond_to?(setter)
          self.send(setter, args)
        else
          raise WardenError.new("Unknown limit #{limit_name}")
        end
      end

      def info
        check_state_in(State::Active, State::Stopped)

        get_info
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

        def finish(path = nil)
          path ||= "/idontexist"
          exit_status_path = File.join(path, "exit_status")
          stdout_path = File.join(path, "stdout")
          stderr_path = File.join(path, "stderr")

          exit_status = File.read(exit_status_path) if File.exist?(exit_status_path)
          exit_status = exit_status.to_i if exit_status && !exit_status.empty?
          stdout_path = nil unless File.exist?(stdout_path)
          stderr_path = nil unless File.exist?(stderr_path)

          status = [exit_status, stdout_path, stderr_path]
          debug "job exit status: #{exit_status}"

          resume(status)
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
