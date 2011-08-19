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

module PackageCache
  class PackageCacheApi < Sinatra::Base
    def initialize
      super
      @logger = Logger.new(STDOUT)
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
    end

    def install_directories
      FileUtils.mkdir_p(@inbox_dir) if not Dir.exists? @inbox_dir
      FileUtils.mkdir_p(@downloads_dir) if not Dir.exists? @downloads_dir
      FileUtils.mkdir_p(@cache_dir)  if not Dir.exists? @cache_dir
    end

    def setup_components
      @user_pool = UserPool.new(@logger)
      @user_pool.install_pool($test_pool)

      @inbox = PackageCache::Inbox.new(@inbox_dir, :server, @logger)
      @inbox.purge!

      @downloader = PackageCache::GemDownloader.new(@downloads_dir, @logger)
      @downloader.purge!

      @cache = PackageCache::Cache.new(@cache_dir, @logger)
    end

    put '/load/:type/:name' do |type, name|
      if type == 'remote'
        @downloader.download(name)
        gem_path = @downloader.get_gem_path(gem_name)

        #build gem
        #add to cache
      elsif type == 'local'
        puts type,name
        #@loader.load_local_gem(name)
      else
        raise 'invalid type'
      end
    end

  end
end
