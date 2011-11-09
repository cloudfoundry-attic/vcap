class RubyPlugin < StagingPlugin
  include GemfileSupport
  def framework
    'ruby'
  end

  def stage_application
    Dir.chdir(destination_directory) do
      create_app_directories
      copy_source_files
      compile_gems
      create_startup_script
    end
  end

  def start_command
    cmd = @environment[:meta][:command]
    cmd = cmd.sub(/ruby/, "#{local_runtime}")
    cmd = cmd.sub(/rake/, "#{local_runtime} -S rake")
    cmd = cmd.sub(/bundle/,"#{gem_bin_dir}/bundle")
    cmd = cmd.sub(/rackup/, "#{local_runtime} -S rackup")
    cmd
  end

 # Returns a path relative to the 'app' directory.
  def gem_bin_dir
    "./rubygems/ruby/#{library_version}/bin"
  end

  private
  def startup_script
    vars = environment_hash
    if uses_bundler?
       #TODO add local_runtime minus "ruby".  Problem the rackup gem in 1.9.1 is requiring ruby18?  Not so in 1.9.2
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

end
