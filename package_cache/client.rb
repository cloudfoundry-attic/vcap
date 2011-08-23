$:.unshift(File.join(File.dirname(__FILE__)))
require 'rest-client'
require 'inbox'

$test_cache = {:url => 'localhost:3000',
               :inbox_dir => '/home/talg/repo/vcap/package_cache/test/inbox'}
               #:cache_dir => '/home/talg/repo/vcap/package_cache/test/cache'}

module PackageCache
  class Client
    def initialize(cache_addr)
      @cache_url = cache_addr[:url]
      #@cache_dir = cache_dir[:cache_dir]
      @inbox = Inbox.new(cache_addr[:inbox_dir], :client)
    end

    def add_local(path)
      module_name = File.basename(path)
      raise "invalid path" if not File.exist?(path)
      entry_name = @inbox.add_entry(path)
      RestClient.put "#{@cache_url}/load/local/#{entry_name}",''
    end

    def add_remote(module_name)
      RestClient.put "#{@cache_url}/load/remote/#{module_name}",''
    end
  end
end

