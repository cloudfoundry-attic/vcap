$:.unshift(File.join(File.dirname(__FILE__)))
require 'sinatra/base'
require 'logger'
require 'inbox'
require 'cache'
require 'fileutils'
require 'lib/vdebug'
require 'gem_downloader'
require 'gem_builder'
require 'lib/user_pool'
require 'lib/debug_formatter'

module PackageCache
  class PackageCacheApi < Sinatra::Base
    def initialize
      super
      @logger = Logger.new(STDOUT)
      @logger.formatter = DebugFormatter.new
      if Process.uid != 0
        @logger.error "Package Cache must be run as root."
        exit 1
      end
      @logger.info("Bringing up package cache...")
      set_directories
      begin
        install_directories
        setup_components
      rescue => e
        @logger.error("startup up failed with exception")
        log_exception(e)
        exit 1
      end
      @logger.info("Package cache started...")
    end

    def log_exception(e)
      begin
        @logger.error "Exception Caught (#{e.class.name}): #{e.to_s}"
        @logger.error e
      rescue
        # Do nothing
      end
    end

    def set_directories
      @inbox_dir = 'test/inbox'
      @downloads_dir = 'test/downloads'
      @cache_dir = 'test/cache'
      @build_dir = 'test/builds'
    end

    def install_directories
      FileUtils.mkdir_p(@inbox_dir) if not Dir.exists? @inbox_dir
      FileUtils.mkdir_p(@downloads_dir) if not Dir.exists? @downloads_dir
      FileUtils.mkdir_p(@cache_dir)  if not Dir.exists? @cache_dir
      FileUtils.mkdir_p(@build_dir)  if not Dir.exists? @build_dir
    end

    def setup_components
      @user_pool = UserPool.new(@logger)
      @user_pool.install_pool($test_pool)

      @inbox = PackageCache::Inbox.new(@inbox_dir, :server, @logger)
      @inbox.purge!

      @downloader = PackageCache::GemDownloader.new(@downloads_dir, @logger)
      @downloader.purge!

      @cache = PackageCache::Cache.new(@cache_dir, @logger)
      #XXX make this purge configurable.
      @cache.purge!
    end

    put '/load/:type/:name' do |type, gem_name|
        if type == 'remote'
          @downloader.download(gem_name)
          gem_path = @downloader.get_gem_path(gem_name)
        elsif type == 'local'
          @inbox.secure_import_entry(gem_name)
          gem_path = @inbox.get_entry(gem_name)
        else
          raise 'invalid type'
        end
        begin
          user = @user_pool.alloc_user
          builder = PackageCache::GemBuilder.new(user, @build_dir, @logger)
          builder.import_gem(gem_path, :rename)
          builder.build
          package_path = builder.get_package
          @cache.add_by_rename!(package_path)
        ensure
          builder.clean_up!
          @user_pool.free_user(user) if user != nil
        end
    end
  end
end
