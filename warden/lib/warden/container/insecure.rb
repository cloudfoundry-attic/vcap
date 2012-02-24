require "warden/errors"
require "warden/container/base"
require "tempfile"
require "socket"

module Warden

  module Container

    class Insecure < Base

      def self.setup(config={})
        # noop
      end

      def do_create
        sh "#{root_path}/create.sh #{handle}"
        debug "insecure container created"
      end

      def do_stop
        sh "#{container_path}/stop.sh"
        debug "insecure container stopped"
      end

      def do_destroy
        sh "#{root_path}/destroy.sh #{handle}"
        debug "insecure container destroyed"
      end

      def create_job(script)
        job = Job.new(self)

        child = DeferredChild.new(File.join(container_path, "run.sh"), :input => script)

        child.callback do
          job.resume [child.exit_status, child.out, child.err]
        end

        child.errback do |err|
          job.resume [nil, nil, nil]
        end

        job
      end

      # Nothing has to be done to map an external port to an insecure
      # container. The container lives in the same kernel namespaces as all
      # other processes, so it has to share its ip space them. To make it more
      # likely for a process inside the insecure container to bind to this
      # inbound port, we grab and return an ephemeral port.
      def do_net_in
        socket = TCPServer.new("0.0.0.0", 0)
        socket.setsockopt(Socket::SOL_SOCKET, Socket::SO_REUSEADDR, 1)
        socket.do_not_reverse_lookup = true
        port = socket.addr[1]
        socket.close
        port
      end
    end
  end
end
