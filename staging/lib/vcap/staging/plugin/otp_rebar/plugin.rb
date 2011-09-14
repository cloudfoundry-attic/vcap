class OtpRebarPlugin < StagingPlugin
  def runtime_info_for(runtime_name)
    unless @runtime_info
      @runtime_info = YAML::load_file(File.expand_path('../runtime_info.yml', __FILE__))
    end

    @runtime_info[runtime_name]
  end

  # TODO - Is there a way to avoid this without some kind of 'register' callback?
  # e.g. StagingPlugin.register('sinatra', __FILE__)
  def framework
    'otp_rebar'
  end

  def stage_application
    Dir.chdir(destination_directory) do
      create_app_directories
      copy_source_files
      create_startup_script
      rewrite_libs
      update_vm_args
    end
  end

  def start_command
    command_lines = []

    # Users can create a vmc.args file with shell variables (like $VMC_APP_PORT). The contents of
    # this will be appended to the vm.args file.
    if File.exists? 'app/etc/vmc.args'
      File.read('app/etc/vmc.args').lines.each do |l|
        command_lines << "echo #{l.strip.inspect} >>etc/vm.args"
      end
    end

    # Always generate a node name
    command_lines << "echo \"-name erl$VMC_APP_PORT@`hostname`\" >>etc/vm.args"

    # Finally, we can start the app
    command_lines << "sh bin/#{detect_app_name} console"

    command_lines.join("\n")
  end

  private
  def startup_script
    vars = environment_hash
    generate_startup_script(vars)
  end

  # We can't always assume that the libraries being pointed to in the release are compatible with our
  # platform. For instance, if the release is built on a Mac, then included shared libraries won't work
  # on Linux. So we'll rewrite all of the libs that are builtin to be symlinks to the runtime.
  def rewrite_libs
    runtime_version = runtime['version']
    runtime_info = runtime_info_for(runtime_version)
    runtime_dir = "/var/vcap/runtimes/erlang-#{runtime_version}"

    # Ensure that our runtime matches the one that the libraries were packaged for
    start_erl_data = File.read('app/releases/start_erl.data')
    expected_erts = start_erl_data.split(/ /).first
    runtime_erts = runtime_info['erts_version']
    unless expected_erts == runtime_erts
      raise "Application was released with different Erlang version to runtime. Selected Runtime ERTS: #{runtime_erts}, Packaged ERTS: #{expected_erts}"
    end

    # Link in the system runtime
    FileUtils.rm_rf "app/erts-#{runtime_erts}"
    FileUtils.ln_s "#{runtime_dir}/lib/erlang/erts-#{runtime_erts}", "app/erts-#{runtime_erts}"

    builtin = runtime_info['builtins']
    Dir['app/lib/*'].each do |lib_name|
      base_lib_name = File.basename(lib_name)
      if builtin.include? base_lib_name
        # Candidate for replacement
        FileUtils.rm_rf lib_name
        FileUtils.ln_s "#{runtime_dir}/lib/erlang/lib/#{base_lib_name}", lib_name
      end
    end
  end

  # We want to alter the VM so that it doesn't want input, and that it doesn't need the double INT to close.
  def update_vm_args
    existing_args = File.read('app/etc/vm.args')

    # We need to remove any -name declarations, since that would prevent us running multiple instances
    cleaned_args = existing_args.lines.map { |l| if l =~ /^-name .*/ then '' else l end }
    File.open('app/etc/vm.args', 'w') do |f|
      f.puts cleaned_args.join
      f.puts
      f.puts "+B"
      f.puts "-noinput"
    end
  end

  # Detect the name of the application by looking for a startup script matching the .rel files.
  def detect_app_name
    app_files = app_files_matching_patterns

    # We may have multiple releases. Look for app names where we also have a script in bin/ to boot them
    interesting_app_files = app_files.select do |app_file|
      app_name = File.basename(app_file)[0..-5]    # Remove the .rel suffix
      File.exists? "app/bin/#{app_name}"
    end

    appname = if interesting_app_files.length == 1
      File.basename(interesting_app_files.first)[0..-5]    # Remove the .rel suffix
    elsif interesting_app_files.length == 0
      raise "No valid Erlang releases with start scripts found. Cannot start application."
    else
      raise "Multiple Erlang releases with different names found. Cannot start application. (Found: #{interesting_app_files.inspect})"
    end

    # TODO - Currently staging exceptions are not handled well.
    # Convert to using exit status and return value on a case-by-case basis.
    raise "Unable to determine Erlang startup command" unless appname
    appname
  end
end
