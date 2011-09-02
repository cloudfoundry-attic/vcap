$:.unshift(File.join(File.dirname(__FILE__), '..'))
require 'fileutils'
require 'inbox'

TEST_ROOT = File.join Dir.pwd, 'test'
TEST_MODULE = 'fake.gem'
TEST_INBOX_DIR =  File.join TEST_ROOT, 'inbox'
TEST_MODULE_PATH = File.join Dir.pwd, TEST_MODULE

def create_test_file(path)
  test_string = "I am a test file"
  File.open(path, 'w') {|f| f.write(test_string) }
end

begin
  puts "testing inbox module"
  FileUtils.mkdir_p(TEST_INBOX_DIR) if not Dir.exists? TEST_INBOX_DIR

  puts "setting up inbox"
  ib = PackageCache::Inbox.new(TEST_INBOX_DIR, :client)

  puts "creating test file"
  create_test_file(TEST_MODULE_PATH)

  puts "adding test module"
  entry_name =  ib.add_entry(TEST_MODULE_PATH)
  if ib.contains? entry_name
    puts "success!"
  else
    puts "failure!"
  end

  puts "get #{entry_name} got: #{ib.get_entry(entry_name)}"
ensure
  FileUtils.rm_f TEST_MODULE_PATH
end

