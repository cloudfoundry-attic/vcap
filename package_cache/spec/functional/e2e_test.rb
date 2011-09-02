$:.unshift(File.join(File.dirname(__FILE__), '..'))
require 'spec_helper'
require 'client'
require 'fileutils'
require 'gem_util'

TEST_LOCAL_GEM = 'yajl-ruby-0.8.2.gem'
TEST_REMOTE_GEM = 'webmock-1.5.0.gem'

def check_gem_in_cache(client, name, type)
  puts "checking for #{name} in cache"
  path = client.get_package_path(name, type)
  if path
    puts "found it! =), at #{path}"
  else
    puts "couldn't find it =("
  end
end


begin
    enter_test_root
    local_gem_path = File.join Dir.pwd, TEST_LOCAL_GEM
    GemUtil.fetch_remote_gem(TEST_LOCAL_GEM)
    client = VCAP::PackageCache::Client.new

    puts "adding local gem #{local_gem_path} to cache"
    client.add_local(local_gem_path)
    check_gem_in_cache(client, local_gem_path, :local)

    puts "adding remote gem #{TEST_REMOTE_GEM} to cache"
    client.add_remote(TEST_REMOTE_GEM)
    check_gem_in_cache(client, TEST_REMOTE_GEM, :remote)

ensure
  exit_test_root
end



