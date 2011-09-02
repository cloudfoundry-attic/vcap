$LOAD_PATH.unshift(File.expand_path(File.join(File.dirname(__FILE__), '../lib/vcap/package_cache')))
$LOAD_PATH.unshift(File.expand_path(File.join(File.dirname(__FILE__), '../../common/lib')))
require 'rubygems'
require 'fileutils'
require 'rspec/core'
require 'rspec/expectations'
require 'eventmachine'
require 'fiber'
require 'em_fiber_wrap'

def create_test_file(path)
  test_string = "I am a test file"
  File.open(path, 'w') {|f| f.write(test_string) }
end

def enter_test_root
  @old_root = Dir.pwd
  Dir.chdir(TEST_ROOT)
end

def exit_test_root
  Dir.chdir(@old_root)
end

TEST_ROOT = File.join(File.dirname(__FILE__), 'test_root')

puts "setting up TEST_ROOT #{TEST_ROOT}"

FileUtils.mkdir_p(TEST_ROOT) if not Dir.exists? TEST_ROOT

at_exit { puts "removing TEST_ROOT #{TEST_ROOT}"; FileUtils.rm_r(TEST_ROOT) }
