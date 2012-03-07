module RubyAutoconfig
  include GemfileSupport

  AUTO_CONFIG_GEM_NAME= 'cf-autoconfig'
  AUTO_CONFIG_GEM_VERSION= '0.0.2'
  #TODO Ideally we get transitive deps from cf-autoconfig gem, but this is no easy task
  #w/out downloading them every time
  AUTO_CONFIG_GEM_DEPS = [ ['cf-runtime', '0.0.1'], ['crack', '0.3.1'] ]

  def autoconfig_enabled?
    return false if not uses_bundler?
    autoconfig = true
    cf_config_file =  destination_directory + '/app/config/cloudfoundry.yml'
    if File.exists? cf_config_file
      config = YAML.load_file(cf_config_file)
      if config['autoconfig'] == false
        autoconfig = false
      end
    end
    #Return true if user has not explicitly opted out and they are not using cf-runtime gem
    autoconfig && !(uses_cf_runtime?)
  end

  def install_autoconfig_gem
    install_local_gem File.join(File.dirname(__FILE__), 'resources'),"#{AUTO_CONFIG_GEM_NAME}-#{AUTO_CONFIG_GEM_VERSION}.gem",
      AUTO_CONFIG_GEM_NAME,AUTO_CONFIG_GEM_VERSION
    install_gems(AUTO_CONFIG_GEM_DEPS)
    #Add the autoconfig gem to the app's Gemfile
    File.open(destination_directory + '/app/Gemfile', 'a') {
        |f| f.puts("\n" + 'gem "cf-autoconfig"') }
  end

  def uses_cf_runtime?
    bundles_gem? 'cf-runtime'
  end

  def autoconfig_load_path
    return "-I#{gem_dir}/#{AUTO_CONFIG_GEM_NAME}-#{AUTO_CONFIG_GEM_VERSION}/lib" if autoconfig_enabled? && library_version == '1.8'
  end

  def gem_dir
    "$PWD/app/rubygems/ruby/#{library_version}/gems"
  end
end
