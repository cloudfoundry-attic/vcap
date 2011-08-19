$:.unshift(File.join(File.dirname(__FILE__)))
require 'rest-client'
require 'inbox'

$test_cache = {:url => 'localhost:9292', :inbox_dir => 'test/inbox'}

module PackageCache
  class Client
    def initializer(cache_addr)
      @cache_url = cache_addr[:url]
      @inbox = Inbox.new(cache_addr[:inbox_dir])
    end

    def add_local(path)
      module_name = File.basename(path)
      raise "invalid path" if not File.exist?(path)
      @inbox.add_entry(path)
      RestClient.put "#{@cache_url}/load/local/#{module_name}"
    end

    def add_remote(module_name)
      RestClient.put "#{@cache_url}/load/remote/#{module_name}"
    end
  end
end

