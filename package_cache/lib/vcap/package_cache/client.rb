$:.unshift(File.dirname(__FILE__))
$:.unshift(File.join(File.dirname(__FILE__), '..'))

require 'rest-client'
require 'logger'

require 'inbox'
require 'package_cache'
require 'cache_client'
require 'gem_util'

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

  def add_local(path)
    module_name = File.basename(path)
    raise "invalid path" if not File.exist?(path)
    entry_name = @inbox.add_entry(path)
    RestClient.put "#{@cache_addr}/load/local/#{entry_name}",''
  end

  def add_remote(gem_name)
    RestClient.put "#{@cache_addr}/load/remote/#{gem_name}",''
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
    package_name = GemUtil.gem_to_package(gem_name)
    @cache_client.get_package_path(package_name)
  end
end

