$:.unshift(File.join(File.dirname(__FILE__)))
require 'fileutils'
require 'inbox'

TEST_ROOT = File.join Dir.pwd, 'test'
TEST_MODULE = 'fake.gem'
TEST_INBOX_DIR =  File.join TEST_ROOT, 'inbox'
TEST_MODULE_PATH = File.join TEST_ROOT, TEST_MODULE

def create_test_file(path)
  test_string = "I am a test file"
  File.open(path, 'w') {|f| f.write(test_string) }
end

begin
  puts "testing inbox module"
  FileUtils.mkdir_p(TEST_INBOX_DIR) if not Dir.exists? TEST_INBOX_DIR
  ib = PackageCache::Inbox.new(TEST_INBOX_DIR, :server)
  create_test_file(TEST_MODULE_PATH)

  puts "adding test module"
  entry_name =  ib.add_entry(TEST_MODULE_PATH)
  if ib.contains? entry_name
    puts "success!"
  else
    puts "failure!"
  end

  puts "get #{entry_name} got: #{ib.get_entry(entry_name)}"

  puts "trying to import entry"
  ib.secure_import_entry(entry_name)


  puts "purging!"
  ib.purge!
  if not ib.contains?(TEST_MODULE)
     puts "purge! succeeded =)"
  else
    puts "purge! failed =("
  end

ensure
  FileUtils.rm_rf(TEST_ROOT)
end

