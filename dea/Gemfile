source "http://rubygems.org"

gem 'bundler', '>= 1.0.10'
gem 'nats', '>= 0.4.10', :require => 'nats/client'
gem 'eventmachine',  '~> 0.12.10'
gem 'em-http-request', '~> 1.0.0.beta.3', :require => 'em-http'

gem 'rack', :require => ["rack/utils", "rack/mime"]
gem 'rake'
gem 'thin'
gem 'yajl-ruby', :require => ['yajl', 'yajl/json_gem']

gem 'vcap_common', :path => '../common'

group :test do
  gem "rspec"
  gem "rcov"
  gem "ci_reporter"
end
