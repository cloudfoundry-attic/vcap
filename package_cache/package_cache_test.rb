$:.unshift(File.join(File.dirname(__FILE__)))
require 'fileutils'
require 'package_cache'
TEST_PACKAGE = 'testpackage.tgz'
TEST_DIR =  File.join Dir.pwd, 'test_dir'
TEST_CACHE_ROOT = File.join TEST_DIR, 'cache_root'

def create_test_file(path)
  test_string = "I am a test file"
  File.open(path, 'w') {|f| f.write(test_string) }
end

begin
  Dir.mkdir(TEST_DIR) if not Dir.exists? TEST_DIR
  Dir.chdir(TEST_DIR)
  test_package_path = File.join Dir.pwd, TEST_PACKAGE
  Dir.mkdir(TEST_CACHE_ROOT)
  create_test_file(test_package_path)
  pk = PackageCache.new(TEST_CACHE_ROOT)
  puts "adding test package"
  pk.add_by_rename!(test_package_path)
  if pk.contains?(TEST_PACKAGE)
    puts "add succeeded =)"
  else
    puts "add failed =("
  end

  puts "removing  test package"
  pk.remove!(TEST_PACKAGE)
  if not pk.contains?(TEST_PACKAGE)
    puts "remove succeeded =)"
  else
    puts "remove failed =("
  end

  puts "re-adding package"
  create_test_file(test_package_path)
  pk.add_by_rename!(test_package_path)

  puts "purging!"
  pk.purge!
  if not pk.contains?(TEST_PACKAGE)
    puts "purge! succeeded =)"
  else
    puts "purge! failed =("
  end

ensure
  FileUtils.rm_rf(TEST_DIR)
end

