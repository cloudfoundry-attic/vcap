require 'logger'
require 'fileutils'

require 'sinatra/async'
require 'rack/fiber_pool'

require 'inbox'
require 'cache'
require 'gem_builder'
require 'pkg_util'
require 'em_fiber_wrap'
require 'vcap/user_pools/user_pool'

require 'yajl'

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
    @user_pool = VCAP::UserPool.new('package_cache', @logger)

    inbox_dir = VCAP::PackageCache.directories['inbox']
    @inbox = VCAP::PackageCache::Inbox.new(inbox_dir, :server, @logger)

    cache_dir = VCAP::PackageCache.directories['cache']
    @cache = VCAP::PackageCache::Cache.new(cache_dir, @logger)
  end

  def create_builder(type, user)
    build_dir = VCAP::PackageCache.directories['builds']
    case type
    when :gem
      VCAP::PackageCache::GemBuilder.new(user, build_dir, @logger)
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
      normalize_symbol('package_type',type, ['gem']),
      File.basename(name)]
  end

  put '/load/:location/:type/:name' do |location_in, type_in, name_in|
    begin
      status(204)
      result = ''
      location, type, name = normalize_input(location_in, type_in, name_in)
      package_name = PkgUtil.to_package(name)
      if @cache.contains?(package_name)
        @logger.info("#{name} already in cache as #{package_name}.")
        status(200)
      else
        begin
          if location == :local
            @inbox.secure_import_entry(name)
            path = @inbox.get_private_entry(name)
          end
          user = @user_pool.alloc_user
          builder = create_builder(type, user)
          builder.build(location, name, path)
          package_path = builder.get_package
          @cache.add_by_rename!(package_path)
        ensure
          builder.clean_up! if builder != nil
          @user_pool.free_user(user) if user != nil
        end
      end
    rescue => e
      @logger.error("FAILED REQUEST load/#{type_in}/#{name_in}.")
      @logger.error e.message
      @logger.error e.backtrace.join("\n")
      body Yajl::Encoder.encode(e.to_s)
      status(500)
    end
  end
end
