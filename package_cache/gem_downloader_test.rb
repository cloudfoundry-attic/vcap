
$:.unshift(File.join(File.dirname(__FILE__)))
require 'fileutils'
require 'gem_downloader'

TMP_DIR = File.join Dir.pwd, 'tmp'
TEST_GEM = 'yajl-ruby-0.8.2.gem'

def create_test_file(path)
  test_string = "I am a test file"
  File.open(path, 'w') {|f| f.write(test_string) }
end

begin
  Dir.mkdir(TMP_DIR)
  puts "testing downloader module"
  gd = PackageCache::GemDownloader.new(TMP_DIR)

  puts "testing download"
  if gd.download(TEST_GEM) and gd.contains?(TEST_GEM)
    puts "success!"
  else
    puts "failure!"
  end

  puts "get #{TEST_GEM} got: #{gd.get_gem_path(TEST_GEM)}"

  gd.remove_gem!(TEST_GEM)

  if not gd.contains?(TEST_GEM)
     puts "remove! succeeded =)"
  else
    puts "remove! failed =("
  end

  gd.download(TEST_GEM)
  puts "re-adding gem"
  puts "purging!"
  gd.purge!
  if not gd.contains?(TEST_GEM)
     puts "purge! succeeded =)"
  else
    puts "purge! failed =("
  end

ensure
  FileUtils.rm_rf(TMP_DIR)
end

