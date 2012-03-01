require 'vcap/staging/plugin/common'

require File.expand_path('../support/custom_matchers', __FILE__)
require File.expand_path('../support/staging_spec_helpers', __FILE__)

MANIFEST_DIR = File.expand_path('../../lib/vcap/staging/plugin/manifests', __FILE__)

# Created as needed, removed at the end of the spec run.
# Allows us to override staging paths.
STAGING_TEMP = Dir.mktmpdir
StagingPlugin.manifest_root = STAGING_TEMP

RSpec.configure do |config|
  config.include StagingSpecHelpers
  config.before(:all) do
    copy = "cp -a #{File.join(MANIFEST_DIR, '*.yml')} #{STAGING_TEMP}"
    `#{copy}`
    unless $? == 0
      puts "Unable to copy staging manifests. Permissions problem?"
      exit 1
    end
    if ENV['CI_VCAP_RUBY18'] then
      %w(sinatra rails3 rack).each do |framework|
        File.open(File.join(STAGING_TEMP, "#{framework}.yml"), "w") do |file|
          YAML.dump ci_manifests[framework], file
        end
      end
    end
    platform_hash = {}
    File.open(File.join(STAGING_TEMP, 'platform.yml'), 'wb') do |f|
      cache_dir = File.join('/tmp', '.vcap_gems')
      platform_hash['cache'] = cache_dir
      platform_hash['insight_agent'] = "/var/vcap/packages/insight_agent/insight-agent.zip"
      f.print YAML.dump platform_hash
    end
  end
end

at_exit do
  if File.directory?(STAGING_TEMP)
    FileUtils.rm_r(STAGING_TEMP)
  end
end

def ci_manifests
  'rails3' => rails_manifest,
  'sinatra' => sinatra_manifest,
  'rack' => rack_manifest,
end
def rails_manifest
  raise ArgumentError unless ENV['CI_VCAP_RUBY18']
  {
    "name"=>"rails3",
    "runtimes"=> [{
        "ruby18"=> {
          "version"=>"1.8.7",
          "description"=>"Ruby 1.8.7",
          "executable"=>ENV['CI_VCAP_RUBY18'],
          "default"=>true,
          "environment"=> {
            "rails_env"=>"production",
            "bundle_gemfile"=>nil,
            "rack_env"=>"production"}
        }
      }, {
        "ruby19"=> {
          "version"=>"1.9.2p180",
          "description"=>"Ruby 1.9.2",
          "executable"=>"ruby",
          "environment"=> {
            "rails_env"=>"production",
            "bundle_gemfile"=>nil,
            "rack_env"=>"production"}
        }
      }
    ],
    "app_servers"=> [
      "thin"=>{
        "description"=>"Thin",
        "executable"=>false,
        "default"=>true}
    ],
    "detection"=> [
      {"config/application.rb"=>true},
      {"config/environment.rb"=>true}
    ],
    "staged_services"=> [
      {"name"=>"mysql", "version"=>"*"},
      {"name"=>"postgresql", "version"=>"*"}
    ]
  }
end
def sinatra_manifest
  raise NotImplementedError
end
def rack_manifest
  raise NotImplementedError
end
