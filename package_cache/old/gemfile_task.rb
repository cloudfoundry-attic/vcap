require "logger"
require "fileutils"

class GemfileTask

  def initialize(app_dir, library_version, ruby_cmd, base_dir, uid=nil, gid=nil)
    @app_dir         = File.expand_path(app_dir)
    @library_version = library_version
    @cache_base_dir  = File.join(base_dir, @library_version)

    @ruby_cmd = ruby_cmd
    @uid = uid
    @gid = gid

    log_file = File.expand_path(File.join(@app_dir, '..', 'logs', 'staging.log'))
    FileUtils.mkdir_p(File.dirname(log_file))

    @logger = Logger.new(log_file)
    @logger.level = ENV["DEBUG"] ? Logger::DEBUG : Logger::INFO
    @logger.formatter = lambda { |sev, time, pname, msg| "#{msg}\n" }

    @cache  = GemCache.new(File.join(@cache_base_dir, "gem_cache"))
  end

  # Stage the gemfile in a temporary directory that is readable by a secure user
  # We may be able to get away with mv here instead of a cp
  def stage_gemfile_for_install(src, tmp_dir)
    output = `cp #{src} #{tmp_dir} 2>&1`
    if $?.exitstatus != 0
      @logger.debug "Failed copying #{src} to #{tmp_dir}: #{output}"
      return nil
    end

    staged_gemfile = File.join(tmp_dir, File.basename(src))

    output = `chmod -R 0744 #{staged_gemfile} 2>&1`
    if $?.exitstatus != 0
      @logger.debug "Failed chmodding #{tmp_dir}: #{output}"
      nil
    else
      staged_gemfile
    end
  end

  # Perform a gem install from src_dir into a temporary directory
  def install_gem(gemfile_path)
    # Create tempdir that will house everything
    tmp_dir = Dir.mktmpdir
    at_exit do
      user = `whoami`.chomp
      `sudo /bin/chown -R #{user} #{tmp_dir}` if @uid
      FileUtils.rm_rf(tmp_dir)
    end

    # Copy gemfile into tempdir, make sure secure user can read it
    staged_gemfile = stage_gemfile_for_install(gemfile_path, tmp_dir)
    unless staged_gemfile
      @logger.debug "Failed copying gemfile to staging dir for install"
      return nil
    end

    # Create a temp dir that the user can write into (gem install into)
    gem_install_dir = File.join(tmp_dir, 'gem_install_dir')
    begin
      Dir.mkdir(gem_install_dir)
    rescue => e
      @logger.error "Failed creating gem install dir: #{e}"
      return nil
    end

    if @uid
      chmod_output = `/bin/chmod 0755 #{gem_install_dir} 2>&1`
      if $?.exitstatus != 0
        @logger.error "Failed chmodding install dir: #{chmod_output}"
        return nil
      end

      chown_output = `sudo /bin/chown -R #{@uid} #{tmp_dir} 2>&1`
      if $?.exitstatus != 0
        @logger.debug "Failed chowning install dir: #{chown_output}"
        return nil
      end
    end

    @logger.debug("Doing a gem install from #{staged_gemfile} into #{gem_install_dir} as user #{@uid || 'cc'}")
    staging_cmd = "#{@ruby_cmd} -S gem install #{staged_gemfile} --local --no-rdoc --no-ri -E -w -f --ignore-dependencies --install-dir #{gem_install_dir}"
    staging_cmd = "cd / && sudo -u '##{@uid}' #{staging_cmd}" if @uid

    # Finally, do the install
    pid = fork
    if pid
      # Parent, wait for staging to complete
      Process.waitpid(pid)
      child_status = $?

      # Kill any stray processes that the gem compilation may have created
      if @uid
        `sudo -u '##{@uid}' pkill -9 -U #{@uid} 2>&1`
        me = `whoami`.chomp
        `sudo chown -R #{me} #{tmp_dir}`
        @logger.debug "Failed chowning #{tmp_dir} to #{me}" if $?.exitstatus != 0
      end

      if child_status.exitstatus != 0
        @logger.debug("Failed executing #{staging_cmd}")
        nil
      else
        @logger.debug("Success!")
        gem_install_dir
      end
    else
      close_fds
      exec(staging_cmd)
    end
  end

  def close_fds
    3.upto(get_max_open_fd) do |fd|
      begin
        IO.for_fd(fd, "r").close
      rescue
      end
    end
  end

  def get_max_open_fd
    max = 0

    dir = nil
    if File.directory?("/proc/self/fd/") # Linux
      dir = "/proc/self/fd/"
    elsif File.directory?("/dev/fd/") # Mac
      dir = "/dev/fd/"
    end

    if dir
      Dir.foreach(dir) do |entry|
        begin
          pid = Integer(entry)
          max = pid if pid > max
        rescue
        end
      end
    else
      max = 65535
    end

    max
  end

end
