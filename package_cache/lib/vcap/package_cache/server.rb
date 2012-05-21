require 'logger'
require 'fileutils'

require 'sinatra'
require 'yajl'

require 'vcap/user_pools/user_pool'

require 'inbox'
require 'cache'
require 'gem_builder'
require 'pkg_util'

require 'warden_env'
require 'warden_gem_builder'

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
    if @config[:use_warden]
      begin
        env = VCAP::PackageCache::WardenEnv.new
        env.destroy!
      rescue => e
        @logger.warn "warden sanity check failed, make sure warden is running!"
        @logger.error e.message
        @logger.error e.backtrace.join("\n")
        exit 1
      end
      @logger.info "warden enabled..."
    else
      begin
        @user_pool = VCAP::UserPool.new('package_cache', @logger)
      rescue ArgumentError
        @logger.warn $!
        @logger.warn "see the package_cache/INSTALL file for directions on setting up a user pool."
      end
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
      runtimes = @config[:runtimes]
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
    valid_runtimes = @config[:runtimes].keys.map {|k| k.to_s}
    runtime = normalize_symbol('runtime', runtime, valid_runtimes)
    [location, type, name, runtime]
  end

  def user_pool_build(location, type, name, runtime, path)
    begin
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

  def warden_build(location, type, name, runtime, path)
    begin
      build_env = VCAP::PackageCache::WardenEnv.new(@config[:runtimes], @logger)
      builder = VCAP::PackageCache::GemBuild.new(build_env, runtime, @logger)
      builder.copy_in_pkg_src(path, name) if path
      builder.build(location, name)
      package_path = builder.create_package(name, runtime)
      tmp_dir = @directories['tmp']
      package_dst = File.join(tmp_dir, File.basename(package_path))
      builder.copy_out_pkg(package_path, package_dst)
      @cache.add_by_rename!(package_dst)
    rescue => e
      @logger.error e.message
      @logger.error e.backtrace.join("\n")
      raise e
    ensure
      FileUtils.rm_f path if(path && File.exists?(path))
      FileUtils.rm_f package_dst if (package_dst && File.exists?(package_dst))
      builder.clean_up! if builder
    end
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
        if location == :local
          @inbox.secure_import_entry(name)
          path = @inbox.get_private_entry(name)
        end
        if @config[:use_warden]
          warden_build(location, type, name, runtime, path)
        else
          user_pool_build(location, type, name, runtime, path)
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
