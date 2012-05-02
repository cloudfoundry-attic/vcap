require "fileutils"

class NpmPackage

  def initialize(name, version, where, secure_uid, secure_gid,
                 npm_helper, logger, cache)
    @name  = name.chomp
    @version = version.chomp
    @npm_helper = npm_helper
    @secure_uid = secure_uid
    @secure_gid = secure_gid
    @logger = logger
    @cache = cache
    @dst_dir = File.join(where, "node_modules", @name)
  end

  def install
    if url_provided?
      @logger.warn("Failed installing package #{@name}. URLs are not supported")
      return nil
    end

    cached = @cache.get(@name, @version)
    if cached
      return @dst_dir if copy_to_dst(cached)

    else
      @registry_data = get_registry_data

      unless @registry_data.is_a?(Hash) && @registry_data["version"]
        log_name = @version.empty? ? @name : "#{@name}@#{@version}"
        @logger.warn("Failed getting the requested package: #{log_name}")
        return nil
      end

      installed = fetch_build

      if installed
        cached = @cache.put(installed, @name, @registry_data["version"])
        return @dst_dir if copy_to_dst(cached)
      end
    end
  end

  def fetch(source, where)
    Dir.chdir(where) do
      fetched_tarball = "package.tgz"
      cmd = "wget --quiet --retry-connrefused --connect-timeout=5 " +
        "--no-check-certificate --output-document=#{fetched_tarball} #{source}"
      `#{cmd}`
      return unless $?.exitstatus == 0

      package_dir = File.join(where, "package")
      FileUtils.mkdir_p(package_dir)

      fetched_path = File.join(where, fetched_tarball)
      `tar xzf #{fetched_path} --directory=#{package_dir} --strip-components=1 2>&1`
      return unless $?.exitstatus == 0

      File.exists?(package_dir) ? package_dir : nil
    end
  end

  def copy_to_dst(source)
    return unless source && File.exists?(source)
    FileUtils.rm_rf(@dst_dir)
    FileUtils.mkdir_p(@dst_dir)
    `cp -a #{source}/* #{@dst_dir}`
    $?.exitstatus == 0
  end

  # This is done in a similar to ruby gems way until PackageCache is available

  def fetch_build
    tmp_dir = Dir.mktmpdir
    at_exit do
      user = `whoami`.chomp
      `sudo /bin/chown -R #{user} #{tmp_dir}` if @secure_uid
      FileUtils.rm_rf(tmp_dir)
    end

    package_dir = fetch(@registry_data["source"], tmp_dir)
    return unless package_dir

    if @secure_uid
      chown_cmd = "sudo /bin/chown -R #{@secure_uid}:#{@secure_gid} #{tmp_dir} 2>&1"
      chown_output = `#{chown_cmd}`

      if $?.exitstatus != 0
        @logger.error("Failed chowning install dir: #{chown_output}")
        return nil
      end
    end

    cmd = @npm_helper.build_cmd(package_dir)

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

    return package_dir if child_status == 0
  end

  def get_registry_data
    # TODO: 1. make direct request, we need only tarball source
    # 2. replicate npm registry database
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
