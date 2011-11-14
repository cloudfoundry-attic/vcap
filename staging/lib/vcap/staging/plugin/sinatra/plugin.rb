class SinatraPlugin < StagingPlugin
  include GemfileSupport
  def framework
    'sinatra'
  end

  def resource_dir
    File.join(File.dirname(__FILE__), 'resources')
  end

  def stage_application
    Dir.chdir(destination_directory) do
      create_app_directories
      copy_source_files
      setup_autoconfig_script
      add_autoconfig_gem
      compile_gems
      create_startup_script
    end
  end

  def add_autoconfig_gem
    if uses_bundler?
      File.open(File.join(destination_directory, 'app','Gemfile'), 'a') {|f| f.puts('gem "cf-autoconfig"') }
    end
  end

  def setup_autoconfig_script
    sinatra_main = detect_main_file
    FileUtils.cp(File.join(resource_dir,"auto_stage.rb"),File.join(destination_directory,'app'))
    text = File.read(File.join(destination_directory, 'app','auto_stage.rb'))
    replaced_text = text.gsub(/@@MAIN_FILE@@/, sinatra_main)
    File.open(File.join(destination_directory, 'app','auto_stage.rb'), 'w') {|f| f.puts(replaced_text) }
  end

  # Sinatra has a non-standard startup process.
  # TODO - Synthesize a 'config.ru' file for each app to avoid this.
  def start_command
    auto_config_main = 'auto_stage.rb'
    if uses_bundler?
      "#{local_runtime} ./rubygems/ruby/#{library_version}/bin/bundle exec #{local_runtime} ./#{auto_config_main} $@"
    else
      "#{local_runtime} #{auto_config_main} $@"
    end
  end

  private
  def startup_script
    vars = environment_hash
    if uses_bundler?
      vars['PATH'] = "$PWD/app/rubygems/ruby/#{library_version}/bin:$PATH"
      vars['GEM_PATH'] = vars['GEM_HOME'] = "$PWD/app/rubygems/ruby/#{library_version}"
      vars['RUBYOPT'] = '-I$PWD/ruby -rstdsync'
    else
      vars['RUBYOPT'] = "-rubygems -I$PWD/ruby -rstdsync"
    end
    # PWD here is after we change to the 'app' directory.
    generate_startup_script(vars) do
      plugin_specific_startup
    end
  end

  def plugin_specific_startup
    cmds = []
    cmds << "mkdir ruby"
    cmds << 'echo "\$stdout.sync = true" >> ./ruby/stdsync.rb'
    cmds.join("\n")
  end

  # TODO - I'm fairly sure this problem of 'no standard startup command' is
  # going to be limited to Sinatra and Node.js. If not, it probably deserves
  # a place in the sinatra.yml manifest.
  def detect_main_file
    file = app_files_matching_patterns.first
    # TODO - Currently staging exceptions are not handled well.
    # Convert to using exit status and return value on a case-by-case basis.
    raise "Unable to determine Sinatra startup command" unless file
    file
  end

end

