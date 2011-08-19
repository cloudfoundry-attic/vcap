$:.unshift(File.join(File.dirname(__FILE__)))
require 'gem_builder'
require 'gem_util'
require 'fileutils'
TEST_GEM = 'yajl-ruby-0.8.2.gem'
TEST_DIR =  File.join Dir.pwd, 'test_build_dir'
begin
  Dir.mkdir(TEST_DIR) if not Dir.exists? TEST_DIR
  Dir.chdir(TEST_DIR)
  GemUtil.fetch_remote_gem(TEST_GEM)
  gb = PackageCache::GemBuilder.new(1000, TEST_DIR)
  puts "importing gem"
  gb.import_gem(File.join(TEST_DIR, TEST_GEM), :rename)
  puts "building gem"
  gb.build
  puts "getting package"
  package = gb.get_package
  if File.exists? package
    puts "#{package} built successfully"
  else
    puts "#{package} doesn't exist!"
  end
  gb.clean_up!
ensure
  FileUtils.rm_rf(TEST_DIR)
end




