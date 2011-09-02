require 'logger'
require 'fileutils'

require 'sinatra/async'
require 'rack/fiber_pool'

require 'lib/user_pool'

require 'inbox'
require 'cache'
require 'downloader'
require 'gem_builder'
require 'pip_builder'
require 'gem_util'
require 'pip_util'
require 'pkg_util'
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
    @downloader = VCAP::PackageCache::Downloader.new(downloads_dir, @logger)

    cache_dir = VCAP::PackageCache.directories['cache']
    @cache = VCAP::PackageCache::Cache.new(cache_dir, @logger)
  end

  def retrieve_package_src(location, type, name)
    if location == :remote
      case type
      when :gem
        @downloader.download(name, GemUtil.gem_to_url(name))
      when :pip
        @downloader.download(name, PipUtil.pip_to_url(name))
      else
        raise "invalid type #{type}"
      end
      path = @downloader.get_file_path(name)
    elsif location == :local
      @inbox.secure_import_entry(name)
      path = @inbox.get_entry(name)
    else
      raise 'invalid location'
    end
    path
  end

  def create_builder(type, user)
    build_dir = VCAP::PackageCache.directories['builds']
    case type
    when :gem
      VCAP::PackageCache::GemBuilder.new(user, build_dir, @logger)
    when :pip
      VCAP::PackageCache::PipBuilder.new(user, build_dir, @logger)
    else
      raise "invalid type #{type}"
    end
  end

  def normalize_symbol(type, param, valid_set)
    unless valid_set.include? param
      raise "invalid #{type} #{param}"
    end
    param.to_sym
  end

  def normalize_input(location, type, name)
    [ normalize_symbol('location', location, ['local', 'remote']),
      normalize_symbol('package_type',type, ['gem', 'pip']),
      File.basename(name)]
  end

  put '/load/:location/:type/:name' do |location_in, type_in, name_in|
    begin
      location, type, name = normalize_input(location_in, type_in, name_in)
      package_name = PkgUtil.to_package(name)
      src_path = retrieve_package_src(location, type, name)
      if @cache.contains?(package_name)
        @logger.info("#{name} already in cache as #{package_name}.")
        FileUtils.rm_f(src_path)
        status(200)
      else
        begin
          user = @user_pool.alloc_user
          builder = create_builder(type, user)
          builder.import_package_src(src_path)
          builder.build
          package_path = builder.get_package
          @cache.add_by_rename!(package_path)
        ensure
          #builder.clean_up! if builder != nil
          @user_pool.free_user(user) if user != nil
        end
      end
    rescue => e
      @logger.error("FAILED REQUEST load/#{type}/#{name}.")
      @logger.error e.to_s
      status(500)
    end
    status(204)
  end
end
