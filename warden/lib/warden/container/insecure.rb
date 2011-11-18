require "warden/errors"
require "warden/container/base"
require "warden/container/script_handler"
require "warden/container/remote_script_handler"
require "tempfile"

module Warden

  module Container

    class Insecure < Base

      def self.setup
        # noop
      end

      def container_root_path
        File.join(container_path, "root")
      end

      def do_create
        # Create container
        command = "#{root_path}/create.sh #{handle}"
        debug command
        handler = ::EM.popen(command, ScriptHandler)
        handler.yield { error "could not create container" }
        debug "container created"

        # Start container
        command = "#{container_path}/start.sh"
        debug command
        handler = ::EM.popen(command, ScriptHandler)
        handler.yield { error "could not start container" }
        debug "container started"
      end

      def do_destroy
        # Stop container
        command = "#{container_path}/stop.sh"
        debug command
        handler = ::EM.popen(command, ScriptHandler)
        handler.yield { error "could not stop container" }
        debug "container stopped"

        # Destroy container
        command = "rm -rf #{container_path}"
        debug command
        handler = ::EM.popen(command, ScriptHandler)
        handler.yield { error "could not destroy container" }
        debug "container destroyed"
      end

      def do_run(script)
        # Store script in temporary file. This is done because run.sh moves the
        # subshell that actually runs the script to the background, and with
        # that closes its stdin. In addition, we cannot capture stdin before
        # executing the subshell because we cannot shutdown the write side of a
        # socket from EM.
        stdin = Tempfile.new("stdin", container_path)
        stdin.write(script)
        stdin.close

        # Run script
        command = "#{container_path}/run.sh #{stdin.path}"
        debug command
        handler = ::EM.popen(command, RemoteScriptHandler)
        result = handler.yield { error "runner unexpectedly terminated" }
        debug "runner successfully terminated: #{result.inspect}"

        # Mix in path to the container's root path
        status, stdout_path, stderr_path = result
        stdout_path = File.join(container_root_path, stdout_path) if stdout_path
        stderr_path = File.join(container_root_path, stderr_path) if stderr_path
        [status, stdout_path, stderr_path]

      ensure
        stdin.close!
      end
    end
  end
end
