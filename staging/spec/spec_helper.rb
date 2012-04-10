require 'vcap/staging/plugin/common'

require File.expand_path('../support/custom_matchers', __FILE__)
require File.expand_path('../support/staging_spec_helpers', __FILE__)

MANIFEST_DIR = File.expand_path('../../lib/vcap/staging/plugin/manifests', __FILE__)

AUTO_CONFIG_GEM_VERSION = '0.0.3'

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
