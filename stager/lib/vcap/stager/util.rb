require 'fileutils'
require 'rest_client'
require 'uri'


module VCAP
  module Stager
  end
end

module VCAP::Stager::Util
  class << self
    # Downloads the zipped app living at _app_uri_ and stores it in a temporary file.
    #
    # NB: This streams the file to disk.
    #
    # @param   app_uri    String   Uri where one can fetch the app. Credentials should be included
    #                              in the uri (i.e. 'http://user:pass@www.foo.com/bar.zip')
    # @param   dest_path  String   When the app should be saved on disk
    #
    # @return  Net::HTTPResponse
    def fetch_zipped_app(app_uri, dest_path)
      save_app = proc do |resp|
        unless resp.kind_of?(Net::HTTPSuccess)
          raise VCAP::Stager::AppDownloadError,
                "Non 200 status code (#{resp.code})"
        end

        begin
          File.open(dest_path, 'w+') do |f|
            resp.read_body do |chunk|
              f.write(chunk)
            end
          end
        rescue => e
          FileUtils.rm_f(dest_path)
          raise e
        end

        resp
      end

      req = RestClient::Request.new(:url => app_uri,
                                    :method => :get,
                                    :block_response => save_app)
      req.execute
    end

    # Uploads the file living at _droplet_path_ to the uri using a PUT request.
    #
    # NB: This streams the file off of disk in 1k chunks.
    #
    # @param  uri           String  Where the app should be uploaded to
    # @param  droplet_path  String  The location on disk of the droplet to be uploaded
    #
    # @return Net::HTTPResponse
    def upload_droplet(droplet_uri, droplet_path)
      RestClient.post(droplet_uri,
                      :upload => {
                        :droplet => File.new(droplet_path, 'rb')
                      })
    end


    # Runs a command in a subprocess with an optional timeout. Captures stdout, stderr.
    # Not the prettiest implementation, but neither EM.popen nor EM.system exposes
    # a way to capture stderr..
    #
    # NB: Must be called with the EM reactor running.
    #
    # @param command              String  Command to execute
    # @param expected_exitstatus  Integer
    # @param timeout              Integer How long the command can execute for
    # @param blk                  Block   Callback to execute when the command completes. It will
    #                                     be called with a hash of:
    #                                     :success    Bool      True if the command exited with expected status
    #                                     :stdout     String
    #                                     :stderr     String
    #                                     :status     Integer
    #                                     :timed_out  Bool
    def run_command(command, expected_exitstatus=0, timeout=nil, &blk)
      expire_timer   = nil
      timed_out      = false
      stderr_tmpfile = Tempfile.new('stager_stderr')
      stderr_path    = stderr_tmpfile.path
      stderr_tmpfile.close

      pid = EM.system('sh', '-c', "#{command} 2> #{stderr_path}") do |stdout, status|
        EM.cancel_timer(expire_timer) if expire_timer

        begin
          stderr = File.read(stderr_path)
          stderr_tmpfile.unlink
        rescue => e
          logger = VCAP::Logging.logger('vcap.stager.task.run_command')
          logger.error("Failed reading stderr from '#{stderr_path}' for command '#{command}': #{e}")
          logger.error(e)
        end

        res = {
          :success   => status.exitstatus == expected_exitstatus,
          :stdout    => stdout,
          :stderr    => stderr,
          :status    => status,
          :timed_out => timed_out,
        }

        blk.call(res)
      end

      if timeout
        expire_timer = EM.add_timer(timeout) do
          logger = VCAP::Logging.logger('vcap.stager.task.expire_command')
          logger.warn("Killing command '#{command}', pid=#{pid}, timeout=#{timeout}")
          timed_out = true
          EM.system('sh', '-c', "ps --ppid #{pid} -o pid= | xargs kill -9")
        end
      end
    end

  end
end
