class StandalonePlugin < StagingPlugin
  include GemfileSupport
  include RubyAutoconfig

  def framework
    'standalone'
  end

  def stage_application
    Dir.chdir(destination_directory) do
      create_app_directories
      copy_source_files
      #Give everything executable perms, as start command may be a script
      FileUtils.chmod_R(0744, File.join(destination_directory, 'app'))
      runtime_specific_staging
      create_startup_script
      create_stop_script
    end
  end

  private
   def runtime_specific_staging
    if environment[:runtime] =~ /\Aruby/
      compile_gems
      install_autoconfig_gem if autoconfig_enabled?
    elsif environment[:runtime] =~ /\Ajava/
      #Make a temp dir for java.io.tmpdir
      FileUtils.mkdir_p File.join(destination_directory, 'temp')
    end
  end

  def start_command
    environment[:meta][:command]
  end

  def startup_script
    vars = environment_hash
    if environment[:runtime] =~ /\Aruby/
      ruby_startup_script vars
    elsif environment[:runtime] =~ /\Ajava/
      java_startup_script vars
    elsif environment[:runtime] =~ /\Apython/
      python_startup_script vars
    else
      generate_startup_script(vars)
    end
  end

  def ruby_startup_script vars
    if uses_bundler?
      path = vars['PATH'] ? vars['PATH'] : "$PATH"
      vars['PATH'] = "$PWD/app/rubygems/ruby/#{library_version}/bin:#{path}"
      vars['GEM_PATH'] = vars['GEM_HOME'] = "$PWD/app/rubygems/ruby/#{library_version}"
      if autoconfig_enabled?
        vars['RUBYOPT'] = "-I$PWD/ruby #{autoconfig_load_path} -rcfautoconfig -rstdsync"
      else
        vars['RUBYOPT'] = "-I$PWD/ruby -rstdsync"
      end
    else
      vars['RUBYOPT'] = "-rubygems -I$PWD/ruby -rstdsync"
    end
    generate_startup_script(vars) do
      ruby_stdsync_startup
    end
  end

  def ruby_stdsync_startup
    cmds = []
    cmds << "mkdir ruby"
    cmds << 'echo "\$stdout.sync = true" >> ./ruby/stdsync.rb'
    cmds.join("\n")
  end

  def java_startup_script vars
    java_sys_props = "-Djava.io.tmpdir=$PWD/temp"
    vars['JAVA_OPTS'] = "$JAVA_OPTS -Xms#{application_memory}m -Xmx#{application_memory}m #{java_sys_props}"
    generate_startup_script(vars)
  end

  def python_startup_script vars
    #setup python scripts to sync stdout/stderr to files
    vars['PYTHONUNBUFFERED'] = "true"
    generate_startup_script(vars)
  end

  def stop_script
    vars = environment_hash
    generate_stop_script(vars)
  end
end
