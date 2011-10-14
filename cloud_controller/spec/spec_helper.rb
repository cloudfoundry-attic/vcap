# This file is copied to spec/ when you run 'rails generate rspec:install'
ENV["RAILS_ENV"] = 'test'
require File.expand_path("../../config/environment", __FILE__)
require 'rspec/rails'

# Requires supporting ruby files with custom matchers and macros, etc,
# in spec/support/ and its subdirectories.
Dir[Rails.root.join("spec/support/**/*.rb")].each {|f| require f}

RSpec.configure do |config|
  config.mock_with :mocha
  # Remove this line if you're not using ActiveRecord or ActiveRecord fixtures
  config.fixture_path = "#{::Rails.root}/spec/fixtures"
  config.use_transactional_fixtures = true
  config.include CloudSpecHelpers
  config.before(:all) do
    CloudController.resource_pool = FilesystemPool.new

    # Set this to something appropriate if you want to test events in your controllers
    CloudController.events = stub_everything(:black_hole)
    CloudController.logger = stub_everything(:black_hole)
  end

end
