require File.expand_path('../database_support', __FILE__)

class Rails3Plugin < StagingPlugin
  include GemfileSupport
  include RailsDatabaseSupport

  def framework
    'rails3'
  end

  # PWD here is after we change to the 'app' directory.
  def start_command
    if uses_bundler?
      # Specify Thin if the app bundled it; otherwise let Rails figure it out.
      server_script = thin? ? "server thin" : "server"
      "#{local_runtime} #{gem_bin_dir}/bundle exec #{local_runtime} #{gem_bin_dir}/rails #{server_script} $@"
    else
      "#{local_runtime} -S thin -R config.ru $@ start"
    end
  end

  # Returns a path relative to the 'app' directory.
  def gem_bin_dir
    "./rubygems/ruby/#{library_version}/bin"
  end

  def migration_command
    if uses_bundler?
      "#{local_runtime} #{gem_bin_dir}/bundle exec #{local_runtime} #{gem_bin_dir}/rake db:migrate --trace"
    else
      "#{local_runtime} -S rake db:migrate --trace"
    end
  end

  def stage_application
    Dir.chdir(destination_directory) do
      create_app_directories
      copy_source_files
      compile_gems
      configure_database # TODO - Fail if we just configured a database that the user did not bundle a driver for.
      create_asset_plugin if disables_static_assets?
      create_startup_script
    end
  end

  def startup_script
    vars = environment_hash
    # PWD here is before we change to the 'app' directory.
    if uses_bundler?
      local_bin_path = File.dirname(runtime['executable'])
      vars['PATH'] = "$PWD/app/rubygems/ruby/#{library_version}/bin:#{local_bin_path}:/usr/bin:/bin"
      vars['GEM_PATH'] = vars['GEM_HOME'] = "$PWD/app/rubygems/ruby/#{library_version}"
    end
    vars['RUBYOPT'] = '-I$PWD/ruby -rstdsync'
    generate_startup_script(vars) do
      cmds = ['mkdir ruby', 'echo "\$stdout.sync = true" >> ./ruby/stdsync.rb']
      cmds << <<-MIGRATE
if [ -f "$PWD/app/config/database.yml" ] ; then
  cd app && #{migration_command} >>../logs/migration.log 2>> ../logs/migration.log && cd ..;
fi
      MIGRATE
      cmds.join("\n")
      end
  end

  # Rails applications often disable asset serving in production mode, and delegate that to
  # nginx or similar. We re-enable it with a plugin as needed.
  def disables_static_assets?
    environment = ''
    prod_env = File.join(destination_directory, 'app', 'config', 'environments', 'production.rb')
    if File.exists?(prod_env)
      environment = File.read(prod_env)
    end
    environment =~ /serve_static_assets\s*=\s*(false|nil)/
  end

  # Generates a trivial Rails plugin that re-enables static asset serving at boot.
  def create_asset_plugin
    init_code = <<-BODY
Rails::Application.configure do
  config.serve_static_assets = true
end
    BODY
    plugin_dir = File.join(destination_directory, 'app', 'vendor', 'plugins', 'serve_static_assets')
    FileUtils.mkdir_p(plugin_dir)
    init_script = File.join(plugin_dir, 'init.rb')
    File.open(init_script, 'wb') do |fh|
      fh.puts(init_code)
    end
    FileUtils.chmod(0600, init_script)
  end
end

