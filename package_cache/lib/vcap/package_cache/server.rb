require 'logger'
require 'fileutils'

require 'sinatra'
require 'yajl'

require 'vcap/user_pools/user_pool'

require 'inbox'
require 'cache'
require 'gem_builder'
require 'pkg_util'

module VCAP module PackageCache end end

class VCAP::PackageCache::PackageCacheServer < Sinatra::Base

  def initialize(server_params)
    super
    @logger = server_params[:logger]
    @config = server_params[:config]
    @directories = server_params[:directories]
    @logger.info("Bringing up package cache...")
    begin
      setup_components
    rescue => e
      @logger.error("startup up failed with exception.")
      @logger.error e.to_s
      exit 1
    end
    @logger.info("Package cache started...")
  end

  def setup_components
    begin
      @user_pool = VCAP::UserPool.new('package_cache', @logger)
    rescue ArgumentError
      @logger.warn $!
      @logger.warn "see the package_cache/INSTALL file for directions on setting up a user pool."
    end

    inbox_dir = @directories['inbox']
    @inbox = VCAP::PackageCache::Inbox.new(inbox_dir, @logger)

    cache_dir = @directories['cache']
    @cache = VCAP::PackageCache::Cache.new(cache_dir, @logger)
  end

  def create_builder(type, runtime, user)
    build_dir = @directories['builds']
    case type
    when :gem
      runtimes = @config[:runtimes][type]
      VCAP::PackageCache::GemBuilder.new(user, build_dir, runtimes, @logger)
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

  def normalize_input(location, type, name, runtime)
    location = normalize_symbol('location', location, ['local', 'remote'])
    type = normalize_symbol('package_type',type, ['gem'])
    name = File.basename(name)
    valid_runtimes = @config[:runtimes][type].keys.map {|k| k.to_s}
    runtime = normalize_symbol('runtime', runtime, valid_runtimes)
    [location, type, name, runtime]
  end

  put '/load/:location/:type/:name/:runtime' do |location_in, type_in, name_in, runtime_in|
    begin
      status(204)
      result = ''
      location, type, name, runtime = normalize_input(location_in, type_in,
                                                      name_in, runtime_in)
      package_name = PkgUtil.to_package(name, runtime)
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
          builder = create_builder(type, runtime, user)
          builder.build(location, name, path, runtime)
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
