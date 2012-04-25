require "fileutils"

class NpmPackage

  def initialize(name, version, modules_dir, secure_uid, secure_gid,
                 npm_helper, logger, cache)
    @name  = name.chomp
    @version = version.chomp
    @resolved_version = nil
    @npm_helper = npm_helper
    @secure_uid = secure_uid
    @secure_gid = secure_gid
    @logger = logger
    @cache = cache
    @modules_dir = modules_dir
  end

  def install
    if url_provided?
      @logger.warn("Failed installing package #{@name}. URLs are not supported")
      return nil
    end

    resolved = resolved_version_data

    unless resolved.is_a?(Hash) && resolved["version"]
      log_name = @version.empty? ? @name : "#{@name}@#{@version}"
      @logger.warn("Failed getting the requested package: #{log_name}")
      return nil
    end

    @resolved_version = resolved["version"]

    cached = @cache.get(@name, @resolved_version)
    if cached
      copy_to_app(cached)

    else
      installed = safe_install
      if installed
        copy_to_app(installed)

        @cache.put(installed, @name, @resolved_version)
      end
    end
  end

  def copy_to_app(source)
    return unless source && File.exist?(source)
    dst_dir = File.join(@modules_dir, @name)
    FileUtils.rm_rf(dst_dir)
    FileUtils.mkdir_p(dst_dir)
    `cp -a #{source}/* #{dst_dir}`
    $?.exitstatus == 0
  end

  # This is done in a similar to ruby gems way until PackageCache is available

  def safe_install
    tmp_dir = Dir.mktmpdir
    at_exit do
      user = `whoami`.chomp
      `sudo /bin/chown -R #{user} #{tmp_dir}` if @secure_uid
      FileUtils.rm_rf(tmp_dir)
    end

    install_dir = File.join(tmp_dir, 'install')
    npm_tmp_dir = File.join(tmp_dir, 'tmp')
    npm_cache_dir = File.join(tmp_dir, 'cache')

    begin
      Dir.mkdir(install_dir)
      Dir.mkdir(npm_tmp_dir)
      Dir.mkdir(npm_cache_dir)
    rescue => e
      @logger.error("Failed creating npm install directories: #{e}")
      return nil
    end

    if @secure_uid
      chown_cmd = "sudo /bin/chown -R #{@secure_uid}:#{@secure_gid} #{tmp_dir} 2>&1"
      chown_output = `#{chown_cmd}`

      if $?.exitstatus != 0
        @logger.error("Failed chowning install dir: #{chown_output}")
        return nil
      end
    end

    package_link = "#{@name}@#{@resolved_version}"

    cmd = @npm_helper.install_cmd(package_link, install_dir, npm_cache_dir,
                                  npm_tmp_dir, @secure_uid, @secure_gid)
    if @secure_uid
      cmd ="sudo -u '##{@secure_uid}' sg #{secure_group} -c \"cd #{tmp_dir} && #{cmd}\" 2>&1"
    else
      cmd ="cd #{tmp_dir} && #{cmd}"
    end

    output = nil
    IO.popen(cmd) do |io|
      output = io.read
    end
    child_status = $?.exitstatus

    if child_status != 0
      @logger.warn("Failed installing package: #{@name}")
      if output =~ /npm not ok/
        output.lines.grep(/^npm ERR! message/) do |error_message|
          @logger.warn(error_message.chomp)
        end
      end
    end

    if @secure_uid
      # Kill any stray processes that the npm compilation may have created
      `sudo -u '##{@secure_uid}' pkill -9 -U #{@secure_uid} 2>&1`
      me = `whoami`.chomp
      `sudo chown -R #{me} #{tmp_dir}`
      @logger.debug("Failed chowning #{tmp_dir} to #{me}") if $?.exitstatus != 0
    end

    package_dir = File.join(install_dir, "node_modules", @name)

    return package_dir if child_status == 0

  end

  def resolved_version_data
    package_link = "#{@name}@\"#{@version}\""
    output = `#{@npm_helper.versioner_cmd(package_link)} 2>&1`
    if $?.exitstatus != 0 || output.empty?
      return nil
    else
      begin
        resolved = Yajl::Parser.parse(output)
      rescue Exception=>e
        return nil
      end
    end
    return resolved
  end

  private

  def url_provided?
    @version =~ /^http/ or @version =~ /^git/
  end

  def secure_group
    group_name = `awk -F: '{ if ( $3 == #{@secure_gid} ) { print $1 } }' /etc/group`
    group_name.chomp
  end
end
