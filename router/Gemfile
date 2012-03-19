source "http://rubygems.org"

gem 'bundler', '>= 1.0.10'
gem 'rake'
gem 'nats', :require => 'nats/client'
gem 'eventmachine'

gem "http_parser.rb", :require => "http/parser"
gem "yajl-ruby", :require => ["yajl", "yajl/json_gem"]

gem 'vcap_common', '~> 1.0.9'
gem 'vcap_logging', :require => ['vcap/logging']

group :test do
  gem "rspec"
  gem "rcov"
  gem "ci_reporter"
end
