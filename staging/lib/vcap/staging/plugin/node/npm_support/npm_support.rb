require "logger"
require "fileutils"
require "timeout"

module NpmSupport

  def compile_node_modules
    # npm provided?
    return nil unless runtime["npm"]

    cache_base_dir = StagingPlugin.platform_config["cache"]
    @library_version = library_version
    @cache_dir  = File.join(cache_base_dir, "node_modules", @library_version)
    @npm_cache_dir = File.join(@cache_dir, "npm_cache")
    @app_dir = File.expand_path(File.join(destination_directory, "app"))
    @npm_cmd = npm_cmd

    setup_logger
    install_node_modules
  end

  def get_dependencies
    @package_config["dependencies"] if @package_config
  end

  def library_version
    environment[:runtime] == "node06" ? "06" : "04"
  end

  def npm_cmd
    safe_env = [ "HTTP_PROXY", "HTTPS_PROXY", "NO_PROXY", "C_INCLUDE_PATH", "LIBRARY_PATH" ].map { |e| "#{e}='#{ENV[e]}'" }.join(" ")
    safe_env << " LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8"
    safe_env << " PATH=#{File.dirname(runtime["executable"])}:$PATH"
    if runtime["npm"] =~ /\.js$/
      "#{safe_env} #{runtime["executable"]} #{runtime["npm"]}"
    else
      "#{safe_env} #{runtime["npm"]}"
    end
  end

  def install_node_modules
    missing = {}
    @logger.info("Installing dependencies. Node version #{runtime["version"]}")
    # Rebuilding user's node modules
    user_node_modules = []
    node_modules_dir = File.join(@app_dir, "node_modules")
    if File.exist?(node_modules_dir)
      user_node_modules = Dir.entries(node_modules_dir)
      user_node_modules.reject! { |nm| nm == "." || nm == ".." }
      rebuild_packages unless user_node_modules.empty?
    end

    # npm install support only if dependencies provided in package.json
    dependencies = get_dependencies
    return unless dependencies

    dependencies.each do |package_name, package_version|
      unless user_node_modules.include?(package_name)
        missing[package_name] = package_version
      end
    end

    unless missing.empty?
      missing.each do |package_name, package_version|
        install_package(package_name, package_version)
      end
    end
  end

  def rebuild_packages
    output = `#{@npm_cmd} rebuild --prefix #{@app_dir} #{npm_cf_args} 2>&1`
    process_npm_output(output)
  end

  def resolve_package_link(package_name, package_version)
    "#{package_name}@\"#{package_version}\""
  end

  def install_package(package_name, package_version)
    package_link = resolve_package_link(package_name, package_version)
    Dir.mktmpdir do |tmp_dir|
      cmd = "#{@npm_cmd} install #{package_link} #{npm_cf_args} --prefix #{@app_dir}" +
        " --cache #{@npm_cache_dir} --tmp #{tmp_dir} --non-global true" +
        " --rollback true 2>&1"
      output = ""

      npm_io = IO.popen(cmd)

      # npm registry is down? check if download started
      fetching = false
      timeout = 10
      loop do
        # copying from npm registry or cache
        if Dir.entries(tmp_dir).size > 2 or
            File.exist?(File.join(@app_dir, "node_modules", package_name))
          fetching = true
          break
        end
        break if timeout <= 0
        timeout = timeout - 0.5
        sleep(0.5)
      end

      if fetching
        output = npm_io.read
        process_npm_output(output)
      else
        @logger.fatal("Failed installing modules: connection timeout to npm registry")
        # kill all npm processes
        npm_child_pids = []
        pipe = IO.popen("ps -ef | grep #{npm_io.pid}")
        pipe.readlines.each do |line|
          ps_fields = line.split(/\s+/)
          if (ps_fields[2] == npm_io.pid.to_s && ps_fields[1] != pipe.pid.to_s) then
            npm_child_pids << ps_fields[1].to_i
          end
        end
        npm_child_pids.each do |pid|
          kill_pid(pid)
        end
        kill_pid(nom_io.pid)
      end
    end
  end

  def kill_pid(pid)
    begin
      Process.kill(9, pid)
    rescue Errno::ESRCH
    end
  end

  def npm_cf_args
    "--node_version #{runtime["version"]}" +
    " --production true --color false --loglevel error"
  end

  def process_npm_output(output)
    if $?.exitstatus != 0
      @logger.info("Failed installing dependencies")
    end
    if output =~ /npm not ok/
      output.lines.grep(/^npm ERR! message/) do |error_message|
        @logger.info(error_message.chomp)
      end
    end
  end

  def setup_logger
    log_file = File.expand_path(File.join(@app_dir, "..", "logs", "staging.log"))
    FileUtils.mkdir_p(File.dirname(log_file))

    @logger = Logger.new(log_file)
    @logger.level = ENV["DEBUG"] ? Logger::DEBUG : Logger::INFO
    @logger.formatter = lambda { |sev, time, pname, msg| "#{msg}\n" }
  end
end
