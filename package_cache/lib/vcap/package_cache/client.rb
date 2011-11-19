require 'rest-client'
require 'logger'

$:.unshift(File.join(File.dirname(__FILE__), '..'))
require 'package_cache'

require 'inbox'
require 'cache_client'
require 'errors'

module VCAP module PackageCache end end

class VCAP::PackageCache::Client
  def initialize(logger = nil)
    @logger = logger || Logger.new(STDOUT)
    config_file = VCAP::PackageCache::Config::DEFAULT_CONFIG_PATH
    VCAP::PackageCache.init(config_file)
    config = VCAP::PackageCache.config
    setup_client(config)
  end

  def setup_client(config)
    #XXX validate that end-point exists and we can connect to it.
    @cache_addr = "127.0.0.1:#{config[:listen_port]}"
    cache_dir = VCAP::PackageCache.directories['cache']
    inbox_dir  = VCAP::PackageCache.directories['inbox']
    @inbox = VCAP::PackageCache::Inbox.new(inbox_dir, :client, @logger)
    @logger.info("setup package cache client on #{@cache_addr}: #{inbox_dir}")
    @cache_client = VCAP::PackageCache::CacheClient.new(cache_dir, @logger)
  end

  def add_package(location, type, id)
    begin
      if location == :remote
        name = id
        response = RestClient.put "#{@cache_addr}/load/remote/#{type}/#{name}",''
      elsif location == :local
        path = id
        raise "invalid path" if not File.exist?(path)
        entry_name = @inbox.add_entry(path)
        response = RestClient.put "#{@cache_addr}/load/local/#{type}/#{entry_name}",''
      else
        raise VCAP::PackageCache::ClientError.new("invalid location")
      end
    rescue => e
      @logger.error "PackageCache Error."
      if e.respond_to?('response')
        raise VCAP::PackageCache::ServerError.new(e.response)
      end
      @logger.error e.message
      @logger.error e.backtrace.join("\n")
    end
  end

  #XXX seems like file_to_entry_name should be renamed to reflect its
  #XXX function more clearly.
  def get_package_path(gem_path, type)
    if type == :remote
      gem_name = File.basename(gem_path)
    elsif type == :local
       gem_name = @inbox.file_to_entry_name(gem_path)
    else
      raise "invalid package type"
    end
    package_name = PkgUtil.to_package(gem_name)
    @cache_client.get_package_path(package_name)
  end
end

