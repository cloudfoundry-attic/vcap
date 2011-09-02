$:.unshift(File.dirname(__FILE__))
require 'logger'
require 'fileutils'

require 'sinatra/async'
require 'rack/fiber_pool'

require 'lib/user_pool'

require 'inbox'
require 'cache'
require 'gem_downloader'
require 'gem_builder'
require 'gem_util'
require 'em_fiber_wrap'

module VCAP module PackageCache end end

class VCAP::PackageCache::PackageCacheServer < Sinatra::Base
  register Sinatra::Async
  use Rack::FiberPool

  def initialize(logger)
    super
    @logger = logger
    @logger.info("Bringing up package cache...")
    begin
      em_fiber_wrap{ setup_components }
    rescue => e
      @logger.error("startup up failed with exception.")
      @logger.error e.to_s
      exit 1
    end
    @logger.info("Package cache started...")
  end

  def setup_components
    @user_pool = VCAP::UserPool.new(VCAP::UserPool::Defs::PACKAGE_CACHE_POOL, @logger)
    @user_pool.install_pool

    inbox_dir = VCAP::PackageCache.directories['inbox']
    @inbox = VCAP::PackageCache::Inbox.new(inbox_dir, :server, @logger)

    downloads_dir = VCAP::PackageCache.directories['downloads']
    @downloader = VCAP::PackageCache::GemDownloader.new(downloads_dir, @logger)

    cache_dir = VCAP::PackageCache.directories['cache']
    @cache = VCAP::PackageCache::Cache.new(cache_dir, @logger)
  end

  def retrieve_gem(type, gem_name)
    if type == 'remote'
      @downloader.download(gem_name)
      gem_path = @downloader.get_gem_path(gem_name)
    elsif type == 'local'
      @inbox.secure_import_entry(gem_name)
      gem_path = @inbox.get_entry(gem_name)
    else
      raise 'invalid type'
    end
    gem_path
  end

  put '/load/:type/:name' do |type, gem_name|
    begin
      gem_path = retrieve_gem(type, gem_name)
      package_name = GemUtil.gem_to_package(File.basename(gem_path))
      if @cache.contains?(package_name)
        @logger.info("#{gem_name} already in cache as #{package_name}.")
        FileUtils.rm_f(gem_path)
        status(200)
      else
        begin
          user = @user_pool.alloc_user
          build_dir = VCAP::PackageCache.directories['builds']
          builder = VCAP::PackageCache::GemBuilder.new(user, build_dir, @logger)
          builder.import_gem(gem_path, :rename)
          builder.build
          package_path = builder.get_package
          @cache.add_by_rename!(package_path)
        ensure
          builder.clean_up! if builder != nil
          @user_pool.free_user(user) if user != nil
        end
      end
    rescue => e
      @logger.error("FAILED REQUEST load/#{type}/#{gem_name}.")
      @logger.error e.to_s
      status(500)
    end
    status(204)
  end
end
