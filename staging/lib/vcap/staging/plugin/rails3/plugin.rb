require File.expand_path('../database_support', __FILE__)
require 'uuidtools'

class Rails3Plugin < StagingPlugin
  include GemfileSupport
  include RailsDatabaseSupport
  include RubyAutoconfig

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

  def console_command
   if uses_bundler?
      "#{local_runtime} #{gem_bin_dir}/bundle exec #{local_runtime} cf-rails-console/rails_console.rb"
    else
      "#{local_runtime} cf-rails-console/rails_console.rb"
    end
  end

  def resource_dir
    File.join(File.dirname(__FILE__), 'resources')
  end

  def stage_application
    Dir.chdir(destination_directory) do
      create_app_directories
      copy_source_files
      stage_console
      compile_gems
      if autoconfig_enabled?
        configure_database # TODO - Fail if we just configured a database that the user did not bundle a driver for.
        install_autoconfig_gem
        setup_autoconfig_script
      end
      create_asset_plugin if disables_static_assets?
      create_startup_script
      create_stop_script
    end
  end

  def stage_console
    #Copy cf-rails-console to app
    cf_rails_console_dir = destination_directory + '/app/cf-rails-console'
    FileUtils.mkdir_p(cf_rails_console_dir)
    FileUtils.cp_r(File.join(File.dirname(__FILE__), 'resources','cf-rails-console'),destination_directory + '/app')
    #Generate console access file for caldecott access
    config_file = cf_rails_console_dir + '/.consoleaccess'
    data = {'username' => UUIDTools::UUID.random_create.to_s,'password' => UUIDTools::UUID.random_create.to_s}
    File.open(config_file, 'w') do |fh|
      fh.write(YAML.dump(data))
    end
  end

  def setup_autoconfig_script
    FileUtils.cp(resource_dir+ '/01-autoconfig.rb',destination_directory +
      '/app/config/initializers')
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
    vars['DISABLE_AUTO_CONFIG'] = 'mysql:postgresql'
    generate_startup_script(vars) do
      cmds = ['mkdir ruby', 'echo "\$stdout.sync = true" >> ./ruby/stdsync.rb']
      cmds << <<-MIGRATE
if [ -f "$PWD/app/config/database.yml" ] ; then
  cd app && #{migration_command} >>../logs/migration.log 2>> ../logs/migration.log && cd ..;
fi
      MIGRATE
      cmds << <<-RUBY_CONSOLE
if [ -n "$VCAP_CONSOLE_PORT" ]; then
  cd app
  #{console_command} >>../logs/console.log 2>> ../logs/console.log &
  CONSOLE_STARTED=$!
  echo "$CONSOLE_STARTED" >> ../console.pid
  cd ..
fi
      RUBY_CONSOLE
      cmds.join("\n")
      end
  end

  def stop_script
    vars = environment_hash
    generate_stop_script(vars)
  end

  def stop_command
    cmds = []
    cmds << 'APP_PID=$1'
    cmds << 'APP_PPID=`ps -o ppid= -p $APP_PID`'
    cmds << 'kill -9 $APP_PID'
    cmds << 'kill -9 $APP_PPID'
    cmds << 'SCRIPT=$(readlink -f "$0")'
    cmds << 'SCRIPTPATH=`dirname "$SCRIPT"`'
    cmds << 'CONSOLE_PID=`head -1 $SCRIPTPATH/console.pid`'
    cmds << 'kill -9 $CONSOLE_PID'
    cmds.join("\n")
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
Rails.application.config.serve_static_assets = true
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

