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
        sh "#{root_path}/create.sh #{handle}"
        debug "container created"

        # Start container
        sh "#{container_path}/start.sh"
        debug "container started"
      end

      def do_destroy
        # Stop container
        sh "#{container_path}/stop.sh"
        debug "container stopped"

        # Destroy container
        sh "rm -rf #{container_path}"
        debug "container destroyed"
      end

      def create_job(script)
        # Store script in temporary file. This is done because run.sh moves the
        # subshell that actually runs the script to the background, and with
        # that closes its stdin. In addition, we cannot capture stdin before
        # executing the subshell because we cannot shutdown the write side of a
        # socket from EM.
        stdin = Tempfile.new("stdin", container_path)
        stdin.write(script)
        stdin.close

        # Create new job and run script
        job = Job.new(self)
        command = "env job_path=#{container_root_path}/#{job.path} #{container_path}/run.sh #{stdin.path}"
        handler = ::EM.popen(command, RemoteScriptHandler)
        handler.callback { job.finish }

        job
      end
    end
  end
end
