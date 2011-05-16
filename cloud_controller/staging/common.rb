require 'rubygems'
gemfile = File.expand_path('../../Gemfile', __FILE__)
if defined?(Bundler)
  if File.realpath(gemfile) != File.realpath(ENV['BUNDLE_GEMFILE'])
    puts "Incorrect BUNDLE_GEMFILE at staging startup: #{ENV['BUNDLE_GEMFILE']}"
    exit 1
  end
else
  ENV['BUNDLE_GEMFILE'] = gemfile
  require 'bundler/setup'
end

require 'yaml'
require 'yajl'
require 'erb'
require 'active_support/core_ext'
require 'rbconfig'

require 'tmpdir' # TODO - Replace this with something less absurd.
# WARNING WARNING WARNING - Only create temp directories when running as a separate process.
# The Ruby stdlib tmpdir implementation is beyond scary in long-running processes.
# You Have Been Warned.


require File.expand_path('../gemfile_support', __FILE__)
require File.expand_path('../gemfile_task', __FILE__)
require File.expand_path('../gem_cache', __FILE__)


# TODO - Separate the common staging helper methods from the 'StagingPlugin' base class, for more clarity.
# Staging plugins (at least the ones written in Ruby) are expected to subclass this. See ruby/sinatra for a simple example.
class StagingPlugin
  attr_accessor :source_directory, :destination_directory, :environment_json

  def self.staging_root
    File.expand_path('..', __FILE__)
  end

  def self.manifest_root
    ENV['STAGING_CONFIG_DIR'] || File.join(staging_root, 'manifests')
  end

  # This is a digestable version for the outside world
  def self.manifests_info
    @@manifests_info ||= {}
  end

  def self.manifests
    @@manifests ||= {}
  end

  def self.platform_config
    path = File.join(manifest_root, 'platform.yml')
    YAML.load_file(path)
  end

  def self.validate_configuration!
    config = platform_config
    staging_cache_dir = config['cache']
    begin
      # NOTE - Make others as needed for other kinds of package managers.
      FileUtils.mkdir_p File.join(staging_cache_dir, 'gems')
      # TODO - Validate java runtimes as well.
      check_ruby_runtimes
    rescue => ex
      puts "Staging environment validation failed: #{ex}"
      exit 1
    end
  end

  def self.get_ruby_version(exe)
    get_ver  = %{-e "print RUBY_VERSION,'p',RUBY_PATCHLEVEL"}
    `env -i PATH=#{ENV['PATH']} #{exe} #{get_ver}`
  end

  # Checks the existence and version of the Ruby runtimes specified
  # by the sinatra and rails staging manifests.
  def self.check_ruby_runtimes
    %w[sinatra rails3].each do |framework|
      manifests[framework]['runtimes'].each do |hash|
        hash.each do |name, properties|
          exe, ver = properties['executable'], properties['version']
          ver_pattern = Regexp.new(Regexp.quote(ver))
          output = get_ruby_version(exe)
          if $? == 0
            unless output.strip =~ ver_pattern
              raise "#{framework} runtime #{name} version was #{output.strip}, expected to match #{ver}*"
            end
          else
            raise "#{framework} staging manifest has a bad runtime: #{name} (#{output.strip})"
          end
        end
      end
    end
  end

  # Generate a client side consumeable version of the manifest info
  def self.generate_manifests_info
    manifests.each_pair do |name, manifest|

      runtimes = []
      appservers = []

      manifest['runtimes'].each do |runtime|
        runtime.each_pair do |runtime_name, runtime_info|
          runtimes <<  {
            :name => runtime_name,
            :version => runtime_info['version'],
            :description => runtime_info['description'] }
        end
      end

      if manifest['app_servers']
        manifest['app_servers'].each do |appserver|
          appserver.each_pair do |appserver_name, appserver_info|
            appservers <<  {
              :name => appserver_name,
              # :version => appserver_info['version'],
              :description => appserver_info['description'] }
          end
        end
      end

      m = {
        :name => manifest['name'],
        :runtimes => runtimes,
        :appservers => appservers,
        :detection => manifest['detection']
      }
      manifests_info[name] = m

    end
  end

  def self.load_all_manifests
    pattern = File.join(manifest_root, '*.yml')
    Dir[pattern].each do |yaml_file|
      next if File.basename(yaml_file) == 'platform.yml'
      load_manifest(yaml_file)
    end
    generate_manifests_info
  end

  def self.load_plugin_for(framework)
    framework = framework.to_s
    plugin_path = File.join(staging_root, framework, 'plugin.rb')
    require plugin_path
    # This loads the default manifest; if a plugin gets passed an alternate
    # manifest directory, and it finds a framework.yml file, it will replace this.
    manifest_path = File.join(manifest_root, "#{framework}.yml")
    load_manifest(manifest_path)
    Object.const_get("#{framework.camelize}Plugin")
  end

  def self.load_manifest(path)
    framework = File.basename(path, '.yml')
    m = YAML.load_file(path)
    unless m['disabled']
      manifests[framework] = m
    else
      manifests.delete(framework)
    end
  rescue
    puts "Failed to load staging manifest for #{framework} from #{path.inspect}"
    exit 1
  end

  # This returns the staging framework names that claim to recognize the app
  # found in the given +dir+. Order is not specified, and the caller must decide what
  # it plans to do if multiple frameworks can be found in the given directory.
  def self.matching_frameworks_for(dir)
    matched = []
    manifests.each do |name, staging_manifest|
      rules = staging_manifest['detection']
      if rules.all? { |rule| rule_matches_directory?(rule, dir) }
        matched.push(name)
      end
    end
    matched
  end

  def self.default_runtime_for(framework)
    manifest = manifests[framework]
    return nil unless manifest && manifest['runtimes']
    manifest['runtimes'].each do |rt|
      rt.each do |name, rt_info|
        return name if rt_info['default']
      end
    end
  end

  # Exits the process with a nonzero status if ARGV does not contain valid
  # staging args. If you call this in-process in an app server you deserve your fate.
  def self.validate_arguments!
    source, dest, env, manifest_dir, uid, gid = *ARGV
    argfail! unless source && dest && env
    argfail! unless File.directory?(File.expand_path(source))
    argfail! unless File.directory?(File.expand_path(dest))
    argfail! unless String === env
    if manifest_dir
      argfail! unless File.directory?(File.expand_path(manifest_dir))
    end
  end

  def self.argfail!
    puts "Invalid arguments for staging: #{ARGV.inspect}"
    exit 1
  end

  def self.rule_matches_directory?(rule, dir)
    dir = File.expand_path(dir)
    results = rule.map do |glob, what|
      full_glob = File.join(dir, glob)
      case what
      when String
        pattern = Regexp.new(what)
        scan_files_for_regexp(dir, full_glob, pattern).any?
      when true
        scan_files(dir, full_glob).any?
      else
        scan_files(dir, full_glob).empty?
      end
    end
    results.all?
  end

  def self.scan_files(base_dir, glob)
    found = []
    base_dir << '/' unless base_dir.ends_with?('/')
    Dir[glob].each do |full_path|
      matched = block_given? ? yield(full_path) : true
      if matched
        relative_path = full_path.dup
        relative_path[base_dir] = ''
        found.push(relative_path)
      end
    end
    found
  end

  def self.scan_files_for_regexp(base_dir, glob, pattern)
    scan_files(base_dir, glob) do |path|
      matched = false
      File.open(path, 'rb') do |f|
        matched = true if f.read.match(pattern)
      end
      matched
    end
  end

  # If you re-implement this in a subclass:
  # A) Do not change the method signature
  # B) Make sure you call 'super'
  #
  # a good subclass impl would look like:
  # def initialize(source, dest, env = nil, manifest_dir = nil)
  #   super
  #   whatever_you_have_planned
  # end
  def initialize(source_directory, destination_directory, environment_json = nil, manifest_dir = nil, uid=nil, gid=nil)
    @source_directory = File.expand_path(source_directory)
    @destination_directory = File.expand_path(destination_directory)
    @environment_json = environment_json || '{}'
    @manifest_dir = nil
    if manifest_dir
      @manifest_dir = ENV['STAGING_CONFIG_DIR'] = File.expand_path(manifest_dir)
    end

    # Drop privs before staging
    # res == real, effective, saved
    @staging_gid = gid.to_i if gid
    @staging_uid = uid.to_i if uid
  end

  def framework
    raise NotImplementedError, "subclasses must implement a 'framework' method that returns a string"
  end

  def stage_application
    raise NotImplementedError, "subclasses must implement a 'stage_application' method"
  end

  def environment
    @environment ||= Yajl::Parser.parse(environment_json, :symbolize_keys => true)
  end

  def staging_command
    runtime['staging']
  end

  def start_command
    app_server['executable']
  end

  def local_runtime
    '%VCAP_LOCAL_RUNTIME%'
  end

  def application_memory
    if environment[:resources] && environment[:resources][:memory]
      environment[:resources][:memory]
    else
      512 #MB
    end
  end

  def manifest
    @manifest ||= begin
                    if @manifest_dir
                      path = File.join(@manifest_dir, "#{framework}.yml")
                      if File.exists?(path)
                        StagingPlugin.load_manifest(path)
                      else
                        StagingPlugin.manifests[framework]
                      end
                    else
                      StagingPlugin.manifests[framework]
                    end
                  end
  end

  # The specified :runtime, or the default.
  def runtime
    find_in_manifest(:runtimes, :runtime, 'a runtime')
  end

  # The specified :server, or the default.
  def app_server
    find_in_manifest(:app_servers, :server, 'an app server')
  end

  # Looks in the specified +environment+ key. If it is set, looks
  # for a matching entry in the staging manifest and returns it.
  # If not found in the environment, the default is returned.
  # The process will exit if an unknown entry is given in the environment.
  def find_in_manifest(manifest_key, environment_key, what)
    choices = manifest[manifest_key.to_s]
    if entry_name = environment[environment_key.to_sym]
      choices.each do |hash|
        hash.each do |name, attrs|
          return attrs if name.to_s == entry_name
        end
      end
      puts "Unable to find #{what} matching #{entry_name.inspect} in #{choices.inspect}"
      exit 1
    else
      select_default_from choices
    end
  end

  # Environment variables specified on the app supersede those
  # set in the staging manifest for the runtime. Theoretically this
  # would allow a user to run their Rails app in development mode, etc.
  def environment_hash
    @env_variables ||= build_environment_hash
  end

  # Given a list of 'runtimes' or 'app_servers', pick out the
  # one that was marked as default. If none are so marked,
  # the first option listed is returned.
  def select_default_from(declarations)
    listed = Array(declarations)
    chosen = nil
    listed.each do |hash|
      hash.each do |name, properties|
        if properties['default']
          chosen = properties
        else
          chosen ||= properties
        end
      end
    end
    chosen
  end

  # Overridden in subclasses when the framework needs to start from a different directory.
  def change_directory_for_start
    "cd app"
  end

  def generate_startup_script(env_vars = {})
    after_env_before_script = block_given? ? yield : "\n"
    template = <<-SCRIPT
#!/bin/bash
<%= environment_statements_for(env_vars) %>
<%= after_env_before_script %>
<%= change_directory_for_start %>
<%= start_command %> > ../logs/stdout.log 2> ../logs/stderr.log &
STARTED=$!
echo "$STARTED" >> ../run.pid
echo "#!/bin/bash" >> ../stop
echo "kill -9 $STARTED" >> ../stop
echo "kill -9 $PPID" >> ../stop
chmod 755 ../stop
wait $STARTED
    SCRIPT
    # TODO - ERB is pretty irritating when it comes to blank lines, such as when 'after_env_before_script' is nil.
    # There is probably a better way that doesn't involve making the above Heredoc horrible.
    ERB.new(template).result(binding).lines.reject {|l| l =~ /^\s*$/}.join
  end

  # Generates newline-separated exports for the specified environment variables.
  # If the value of one of the keys is false or nil, it will be an 'unset' instead of an 'export'
  def environment_statements_for(vars)
    lines = []
    vars.each do |name, value|
      if value
        lines << "export #{name}=\"#{value}\""
      else
        lines << "unset #{name}"
      end
    end
    lines.sort.join("\n")
  end

  def create_app_directories
    FileUtils.mkdir_p File.join(destination_directory, 'app')
    FileUtils.mkdir_p File.join(destination_directory, 'logs')
  end

  def create_startup_script
    path = File.join(destination_directory, 'startup')
    File.open(path, 'wb') do |f|
      f.puts startup_script
    end
    FileUtils.chmod(0500, path)
  end

  def copy_source_files(dest = nil)
    dest ||= File.join(destination_directory, 'app')
    system "cp -a #{File.join(source_directory, "*")} #{dest}"
  end

  def detection_rules
    manifest['detection']
  end

  def bound_services
    environment[:services] || []
  end

  # Returns all the application files that match detection patterns.
  # This excludes files that are checked for existence/non-existence.
  # Returned pathnames are relative to the app directory:
  # e.g. [sinatra_app.rb, lib/somefile.rb]
  def app_files_matching_patterns
    matching = []
    app_dir = File.join(destination_directory, 'app')
    detection_rules.each do |rule|
      rule.each do |glob, pattern|
        next unless String === pattern
        full_glob = File.join(app_dir, glob)
        files = StagingPlugin.scan_files_for_regexp(app_dir, full_glob, pattern)
        matching.concat(files)
      end
    end
    matching
  end

  # Full path to the Ruby we are running under.
  def current_ruby
    File.join(Config::CONFIG['bindir'], Config::CONFIG['ruby_install_name'])
  end

  # Returns a set of environment clauses, only allowing the names specified.
  def minimal_env(*allowed)
    env = ''
    allowed.each do |var|
      next unless ENV.key?(var)
      env << "#{var}=#{ENV[var]} "
    end
    env.strip
  end

  # Constructs a hash containing the variables associated
  # with the app's runtime.
  def build_environment_hash
    ret = {}
    (runtime['environment'] || {}).each do |key,val|
      ret[key.to_s.upcase] = val
    end
    ret
  end

  # If the manifest specifies a workable ruby, returns that.
  # Otherwise, returns the path to the ruby we were started with.
  def ruby
    @ruby ||= \
    begin
      rb = runtime['executable']
      pattern = Regexp.new(Regexp.quote(runtime['version']))
      output = StagingPlugin.get_ruby_version(rb)
      if $? == 0 && output.strip =~ pattern
        rb
      elsif "#{RUBY_VERSION}p#{RUBY_PATCHLEVEL}" =~ pattern
        current_ruby
      else
        puts "No suitable runtime found. Needs version matching #{runtime['version']}"
        exit 1
      end
    end
  end
end
