require 'vcap/staging'

require File.expand_path('../support/custom_matchers', __FILE__)
require File.expand_path('../support/staging_spec_helpers', __FILE__)

MANIFEST_DIR = File.expand_path('../../lib/vcap/staging/plugin/manifests', __FILE__)

# Created as needed, removed at the end of the spec run.
# Allows us to override staging paths.
tmproot = ENV['HOME'] || '/tmp'
STAGING_TEMP = File.join(tmproot, '.vcap_staging_temp')
ENV['STAGING_CONFIG_DIR'] = STAGING_TEMP

RSpec.configure do |config|
  config.include StagingSpecHelpers
  config.before(:all) do
    unless File.directory?(STAGING_TEMP)
      FileUtils.mkdir_p(STAGING_TEMP)
      copy = "cp -a #{File.join(MANIFEST_DIR, '*.yml')} #{STAGING_TEMP}"
      `#{copy}`
      unless $? == 0
        puts "Unable to copy staging manifests. Permissions problem?"
        exit 1
      end
      File.open(File.join(STAGING_TEMP, 'platform.yml'), 'wb') do |f|
        cache_dir = File.join(ENV['HOME'], '.vcap_gems')
        f.print YAML.dump('cache' => cache_dir)
      end
    end
  end
end

at_exit do
  if File.directory?(STAGING_TEMP)
    FileUtils.rm_r(STAGING_TEMP)
  end
end
