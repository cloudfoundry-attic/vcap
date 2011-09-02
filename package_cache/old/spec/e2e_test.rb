$:.unshift(File.join(File.dirname(__FILE__), '..'))
require 'client'
require 'fileutils'
require 'gem_util'

TEST_DIR =  File.join Dir.pwd, 'test_client_dir'
TEST_LOCAL_GEM = 'yajl-ruby-0.8.2.gem'
TEST_REMOTE_GEM = 'webmock-1.5.0.gem'
LOCAL_GEM_PATH = File.join TEST_DIR, TEST_LOCAL_GEM

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
  Dir.mkdir(TEST_DIR) if not Dir.exists? TEST_DIR
  Dir.chdir(TEST_DIR) {
    GemUtil.fetch_remote_gem(TEST_LOCAL_GEM)
    client = VCAP::PackageCache::Client.new

    puts "adding local gem #{LOCAL_GEM_PATH} to cache"
    client.add_local(LOCAL_GEM_PATH)
    check_gem_in_cache(client, LOCAL_GEM_PATH, :local)

    puts "adding remote gem #{TEST_REMOTE_GEM} to cache"
    client.add_remote(TEST_REMOTE_GEM)
    check_gem_in_cache(client, TEST_REMOTE_GEM, :remote)

  }
ensure
  FileUtils.rm_rf(TEST_DIR)
end



