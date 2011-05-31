class RackPlugin < StagingPlugin
  include GemfileSupport
  def framework
    'rack'
  end

  def stage_application
    Dir.chdir(destination_directory) do
      create_app_directories
      copy_source_files
      compile_gems
      create_startup_script
    end
  end

  # Rack has a standard startup process.
  def start_command
    if ! File.exist?("app/Gemfile")
      raise "Rack applications *must* have a Gemfile"      
    end
    "#{local_runtime} -S bundle exec #{local_runtime} #{gem_bin_dir}/thin -R config.ru $@ start"
  end

  private
  
  # Returns a path relative to the 'app' directory.
  def gem_bin_dir
    "./rubygems/ruby/#{library_version}/bin"
  end
  
  def startup_script
    vars = environment_hash
    if uses_bundler?
      vars['PATH'] = "$PWD/app/rubygems/ruby/#{library_version}/bin:$PATH"
      vars['GEM_PATH'] = vars['GEM_HOME'] = "$PWD/app/rubygems/ruby/#{library_version}"
    end
    vars['RUBYOPT'] = "-rubygems -I$PWD/ruby -rstdsync"
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

end

