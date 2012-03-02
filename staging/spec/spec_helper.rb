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
        manifest = YAML.load_file(File.join(STAGING_TEMP, "#{framework}.yml"))
        unless runtimes = manifest['runtimes']
          raise ArgumentError.new("Bad manifest")
        end
        if runtime=runtimes.find {|h| h.include? 'ruby18'}
          runtime['ruby18']['executable'] = ENV['CI_VCAP_RUBY18']
          File.open(File.join(STAGING_TEMP, "#{framework}.yml"), "w") do |file|
            YAML.dump manifest, file
          end
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
  {
    'rails3' => rails_manifest,
    'sinatra' => sinatra_manifest,
    'rack' => rack_manifest,
  }
end
