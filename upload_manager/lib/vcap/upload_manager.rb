require 'thin'
require 'vcap/logging'
require 'logger'

$:.unshift(File.join(File.dirname(__FILE__), 'upload_manager'))
$:.unshift(File.join(File.dirname(__FILE__), '../../../common/lib'))

require 'config'
require 'server'
require 'debug_formatter'

module VCAP
  module UploadManager
    class << self
      attr_accessor :config
      attr_accessor :directories

      def init(config_file)
         puts "Initializing upload manager."
        begin
          config = VCAP::UploadManager::Config.from_file(config_file)
        rescue VCAP::JsonSchema::ValidationError => ve
          puts "ERROR: There was a problem validating the supplied config: #{ve}"
          exit 1
        rescue => e
          puts "ERROR: Failed loading config from file '#{config_file}': #{e}"
          exit 1
        end
        @config = config
      end

      def start_server!
        puts "starting server"
        #XXX need to write a debug formatter that works with matt's stuff.
        #XXX stuck on vanilla ruby logger till then.
        #VCAP::Logging.setup_from_config(@config[:logging])
        #@logger = VCAP::Logging.logger('pcache')
        #@logger.level = Logger::INFO
        @logger = logger = Logger.new(STDOUT)
        logger.formatter = DebugFormatter.new
        logger.info("logger initialized")
        #XXX prolly want to split this up, app_packer on local storage, i.e. vcap.local
        #XXX package_store and resource_pool on nfs.
        @directories = setup_directories(@config[:base_dir], logger)
        purge_directory!(@directories['resource_pool']) if @config[:purge_resource_pool_on_startup]
        at_exit { clean_directories } #prevent storage leaks.
        setup_pidfile
        listen_port = config[:listen_port]
        server_params = { :config => @config,
                          :directories => @directories,
                          :logger => @logger}

        # XXX should get thin to use our logger.
        # Thin::Logging.silent = true
        server = Thin::Server.new('0.0.0.0', listen_port) do
           use Rack::CommonLogger
           map "/" do
             run VCAP::UploadManager::UploadManagerServer.new(server_params)
           end
        end
        server.threaded = true
        server.start!
      end

      def setup_directories(base_dir, logger)
        raise "invalid base dir" unless Dir.exists? base_dir
        directories = Hash.new
        dir_names = %w[resource_pool app_packer package_store]
        dir_names.each {|name|
          directories[name] = File.join(base_dir, name)
        }
        directories.each { |name, path|
          logger.debug("setting up #{path}")
          FileUtils.mkdir_p(path) if not Dir.exists?(path)
        }
        directories
      end


      private

      def purge_directory!(path)
        @logger.info("purging #{path}")
        FileUtils.rm_rf Dir.glob("#{path}/*"), :secure => true
      end

      def clean_directories
        tmp_dir_names = %w[app_packer]
        tmp_dir_names.each { |name|
          path = @directories[name]
          purge_directory!(path)
        }
      end

      def setup_pidfile
        begin
          pid_file = VCAP::PidFile.new(@config[:pid_file])
          pid_file.unlink_at_exit
        rescue => e
          puts "ERROR: Can't create upload_manager pid file #{config[:pid_file]}"
          exit 1
        end
      end
    end
  end
end
