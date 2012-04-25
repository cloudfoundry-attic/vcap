require File.expand_path('../npm_support/npm_support', __FILE__)

class NodePlugin < StagingPlugin
  include NpmSupport

  # TODO - Is there a way to avoid this without some kind of 'register' callback?
  # e.g. StagingPlugin.register('sinatra', __FILE__)
  def framework
    'node'
  end

  def stage_application
    Dir.chdir(destination_directory) do
      create_app_directories
      copy_source_files
      read_configs
      compile_node_modules
      create_startup_script
      create_stop_script
    end
  end

  # Let DEA fill in as needed..
  def start_command
    command = package_json_start || guess_main_file
    "%VCAP_LOCAL_RUNTIME% $NODE_ARGS #{command} $@"
  end

  private

  def startup_script
    vars = environment_hash
    generate_startup_script(vars)
  end

  def stop_script
    vars = environment_hash
    generate_stop_script(vars)
  end

  def read_configs
    package = File.join(destination_directory, 'app', 'package.json')
    if File.exists? package
      @package_config = Yajl::Parser.parse(File.new(package, 'r'))
    end
  end

  # detect start script from package.json
  def package_json_start
    if @package_config.is_a?(Hash) &&
        @package_config["scripts"].is_a?(Hash) &&
        @package_config["scripts"]["start"]
      @package_config["scripts"]["start"].sub(/^\s*node\s+/, "")
    end
  end

  def guess_main_file
    file = nil
    js_files = app_files_matching_patterns

    if js_files.length == 1
      file = js_files.first
    else
      %w{server.js app.js index.js main.js application.js}.each do |fname|
        file = fname if js_files.include? fname
      end
    end

    # TODO - Currently staging exceptions are not handled well.
    # Convert to using exit status and return value on a case-by-case basis.
    raise "Unable to determine Node.js startup command" unless file
    file
  end
end

