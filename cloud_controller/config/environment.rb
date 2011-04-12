# FIXME - This process does not yet honor 'database_uri' in the config file.
#
# Load the rails application
require File.expand_path('../application', __FILE__)

if Rails.env.production? && AppConfig[:defaulted]
  $stderr.puts "FATAL: Some important config options were incorrect: #{AppConfig[:defaulted].join(', ')}"
  exit 1
end

# Initialize the rails application
CloudController::Application.initialize!

# Perform final boot and initialization.
# Contains steps that are not necessary for 'rake db:migrate', etc.
unless Rails.env.test? || ENV["CC_NOSTART"]
  require Rails.root.join('config', 'final_stage', 'activate')
end
