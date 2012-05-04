# Used by the core Rakefile and the integration test suite.
# Each has a need to care about component paths, etc.

module CoreComponents
  module_function

  def root
    @root ||= File.expand_path('../..', __FILE__)
  end

  def components
    %w[cloud_controller dea health_manager router stager acm services/redis services/mysql services/mongodb services/postgresql services/neo4j services/rabbit services/memcached]
  end

  def dirs
    components.map {|subdir| File.join(root, subdir) }
  end

  # Changes to each directory in turn, and yields full $PWD to a block.
  def in_each_dir
    dirs.each do |dir|
      Dir.chdir(dir) do
        yield(dir)
      end
    end
  end

  def bundle_environment
    env = "unset BUNDLE_GEMFILE;"
    if ENV['BUNDLE_PATH']
      env << "export BUNDLE_PATH=#{ENV['BUNDLE_PATH']};"
    end
    env
  end
  # Change to each 'core' directory with a Gemfile and run the specified command.
  def for_each_gemfile(command, why = 'install')
    command = "#{bundle_environment}#{command}"
    # We show full command output when --trace is set.
    tracing = Rake.application.options.trace
    dirs.each do |full_path|
      # Skip any components that do not include Gemfiles
      next unless File.exist?(File.join(full_path, 'Gemfile'))
      Dir.chdir(full_path) do
        output = `#{command} 2>&1`
        if $? == 0
          unless tracing
            output = "bundle #{why} successful for #{File.basename(full_path)}"
          end
          puts output
        else
          puts "FATAL: `#{command}` failed in #{full_path}"
          exit 1
        end
      end
    end
  end
end

# vim: ts=2 sw=2 filetype=ruby
