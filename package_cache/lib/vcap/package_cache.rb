#XXX can't assume this gets setup for us because of the client.
$:.unshift(File.join(File.dirname(__FILE__), '..'))
$:.unshift(File.join(File.dirname(__FILE__), '../../../common/lib'))
$:.unshift(File.join(File.dirname(__FILE__), 'package_cache'))

require 'vcap/package_cache/config'
require 'vcap/package_cache/server'
require 'vcap/package_cache/debug_formatter'
require 'thin'
require 'vcap/logging'
require 'logger'


module VCAP
  module PackageCache
    class << self
      attr_accessor :config
      attr_accessor :directories

      def init(config_file)
         puts "Initializing package cache."
        begin
          config = VCAP::PackageCache::Config.from_file(config_file)
        rescue VCAP::JsonSchema::ValidationError => ve
          puts "ERROR: There was a problem validating the supplied config: #{ve}"
          exit 1
        rescue => e
          puts "ERROR: Failed loading config from file '#{config_file}': #{e}"
          exit 1
        end

        @config = config
        init_directories
      end

      def start_server!
        if Process.uid != 0
          puts "Package cache must be run as root."
          exit 1
        end
        #XXX matt's logging stuff, disabled till' I figure out how to setup a new
        #formatter for debugging.
        #VCAP::Logging.setup_from_config(@config[:logging])
        #@logger = VCAP::Logging.logger('pcache')
        @logger = Logger.new(STDOUT)
        @logger.formatter = DebugFormatter.new
        #@logger.level = Logger::INFO
        install_directories
        clean_directories
        purge_directory!(@directories['cache']) if @config[:purge_cache_on_startup]
        at_exit { clean_directories } #prevent storage leaks.
        setup_pidfile
        listen_port = config[:listen_port]

        server_params = {:logger => @logger,
                         :config => @config,
                         :directories => @directories,
          }

        server = Thin::Server.new('127.0.0.1', listen_port) do
           use Rack::CommonLogger
           map "/" do
             run VCAP::PackageCache::PackageCacheServer.new(server_params)
           end
        end
        server.threaded = true
        server.start!
      end

      private
      def purge_directory!(path)
        @logger.info("purging #{path}")
        FileUtils.rm_rf Dir.glob("#{path}/*"), :secure => true
      end

      def clean_directories
        tmp_dir_names = %w[inbox builds]
        tmp_dir_names.each { |name|
          path = @directories[name]
          purge_directory!(path)
        }
      end

      def init_directories
        @directories = Hash.new
        dir_names = %w[inbox cache builds]
        base_dir = @config[:base_dir]
        dir_names.each {|name|
          @directories[name] = File.join(base_dir, name)
        }
      end

      def install_directories
        @directories.each { |name, path|
          @logger.debug("setting up #{path}")
          FileUtils.mkdir_p(path) if not Dir.exists?(path)
        }
      end

      def setup_pidfile
        begin
          pid_file = VCAP::PidFile.new(@config[:pid_file])
          pid_file.unlink_at_exit
        rescue => e
          puts "ERROR: Can't create package_cache pid file #{config[:pid_file]}"
          exit 1
        end
      end

    end
  end
end
