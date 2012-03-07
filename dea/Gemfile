source "http://rubygems.org"

gem 'bundler', '>= 1.0.10'
gem 'nats', :require => 'nats/client'
gem 'eventmachine'
gem 'em-http-request', '~> 1.0.0.beta.3', :require => 'em-http'

gem 'rack', :require => ["rack/utils", "rack/mime"]
gem 'rake'
gem 'thin'
gem 'yajl-ruby', :require => ['yajl', 'yajl/json_gem']
gem 'logging', '>= 1.5.0'

gem 'vcap_common', '~> 1.0.8'
gem 'vcap_logging', :require => ['vcap/logging']

group :test do
  gem "rspec"
  gem "rcov"
  gem "ci_reporter"
end
