# This file is copied to spec/ when you run 'rails generate rspec:install'
ENV["RAILS_ENV"] = 'test'
require File.expand_path("../../config/environment", __FILE__)
require 'rspec/rails'

# Requires supporting ruby files with custom matchers and macros, etc,
# in spec/support/ and its subdirectories.
Dir[Rails.root.join("spec/support/**/*.rb")].each {|f| require f}
MANIFEST_DIR = File.expand_path('../../staging/manifests', __FILE__)

# Created as needed, removed at the end of the spec run.
# Allows us to override staging paths.
tmproot = ENV['HOME'] || '/tmp'
STAGING_TEMP = File.join(tmproot, '.vcap_staging_temp')
ENV['STAGING_CONFIG_DIR'] = STAGING_TEMP

RSpec.configure do |config|
  config.mock_with :mocha
  # Remove this line if you're not using ActiveRecord or ActiveRecord fixtures
  config.fixture_path = "#{::Rails.root}/spec/fixtures"
  config.use_transactional_fixtures = true
  config.include CloudSpecHelpers
  config.include StagingSpecHelpers
  config.before(:all) do
    CloudController.resource_pool = FilesystemPool.new

    # Set this to something appropriate if you want to test events in your controllers
    CloudController.events = stub_everything(:black_hole)

    unless File.directory?(STAGING_TEMP)
      FileUtils.mkdir_p(STAGING_TEMP)
      copy = "cp -a #{File.join(MANIFEST_DIR, '*.yml')} #{STAGING_TEMP}"
      `#{copy}`
      unless $? == 0
        puts "Unable to copy staging manifests. Permissions problem?"
        exit 1
      end
      File.open(File.join(STAGING_TEMP, 'platform.yml'), 'wb') do |f|
        cache_dir = File.join(ENV['HOME'], '.vcap_gems')
        f.print YAML.dump('cache' => cache_dir)
      end
    end
  end
end

at_exit do
  if File.directory?(STAGING_TEMP)
    FileUtils.rm_r(STAGING_TEMP)
  end
end
