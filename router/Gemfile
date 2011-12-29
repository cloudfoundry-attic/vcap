source "http://rubygems.org"

gem 'bundler', '>= 1.0.10'
gem 'rake'
gem 'nats', '>= 0.4.10', :require => 'nats/client'
gem 'eventmachine',  '~> 0.12.11.cloudfoundry.2'
gem "http_parser.rb",  :require => "http/parser"
gem "yajl-ruby", :require => ["yajl", "yajl/json_gem"]
gem "sinatra"

gem 'vcap_common', :path => '../common'
gem 'vcap_logging', :require => ['vcap/logging']

group :test do
  gem "rspec"
  gem "rcov"
  gem "ci_reporter"
end
