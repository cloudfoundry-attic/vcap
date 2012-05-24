source "http://rubygems.org"

gem 'bundler', '>= 1.0.10'
gem 'rake'
gem 'nats', :require => 'nats/client'
gem 'eventmachine', :git => 'git://github.com/cloudfoundry/eventmachine.git', :branch => 'release-0.12.11-cf'

gem "http_parser.rb", :require => "http/parser"
gem "yajl-ruby", :require => ["yajl", "yajl/json_gem"]
gem "sinatra"

gem 'vcap_common', '~> 1.0.9', :git => 'git://github.com/cloudfoundry/vcap-common.git', :ref => 'f6ffe9ad'
gem 'vcap_logging', :require => ['vcap/logging'], :git => 'git://github.com/cloudfoundry/common.git'

group :test do
  gem "rspec"
  gem "rcov"
  gem "ci_reporter"
end
