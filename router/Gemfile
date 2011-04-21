source "http://rubygems.org"

gem 'bundler', '>= 1.0.10'
gem 'rake'
gem 'nats', '>= 0.4.10', :require => 'nats/client'
gem 'eventmachine',  '~> 0.12.10'
gem "http_parser.rb",  :require => "http/parser"
gem "yajl-ruby", :require => ["yajl", "yajl/json_gem"]

gem 'vcap_common', :path => '../common'

group :test do
  gem "rspec"
  gem "rcov"
  gem "ci_reporter"
end
