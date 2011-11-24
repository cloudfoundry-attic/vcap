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
        job = Job.new(self)
        env = { "job_path" => File.join(container_root_path, job.path) }
        child = Child.new(env, File.join(container_path, "run.sh"), :input => script)
        child.callback { job.finish }
        child.errback { job.finish }

        job
      end
    end
  end
end
