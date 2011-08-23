$:.unshift(File.join(File.dirname(__FILE__)))
require 'client'
require 'fileutils'
require 'gem_util'

TEST_DIR =  File.join Dir.pwd, 'test_client_dir'
TEST_LOCAL_GEM = 'yajl-ruby-0.8.2.gem'
TEST_REMOTE_GEM = 'webmock-1.5.0.gem'
LOCAL_GEM_PATH = File.join TEST_DIR, TEST_LOCAL_GEM
begin
  Dir.mkdir(TEST_DIR) if not Dir.exists? TEST_DIR
  Dir.chdir(TEST_DIR) {
    GemUtil.fetch_remote_gem(TEST_LOCAL_GEM)
    client = PackageCache::Client.new($test_cache)

    puts "adding local gem #{LOCAL_GEM_PATH} to cache"
    client.add_local(LOCAL_GEM_PATH)

    puts "adding remote gem #{TEST_REMOTE_GEM} to cache"
    client.add_remote(TEST_REMOTE_GEM)
  }
ensure
  FileUtils.rm_rf(TEST_DIR)
end



