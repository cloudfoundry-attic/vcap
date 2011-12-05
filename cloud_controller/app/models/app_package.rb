class AppPackageError < StandardError
end

class AppPackage
  # This is called with an instance of ActionDispatch::Http::UploadedFile
  # but anything that responds to 'path' with a pathname to a zip file is OK.
  def initialize(app, uploaded_file, resource_descriptors = [])
    @app = app
    @uploaded_file = uploaded_file
    @resource_descriptors = resource_descriptors
    if uploaded_file && !uploaded_file.respond_to?(:path)
      raise ArgumentError, "Usage: AppPackage.new(an_app, a_zipfile, optional_array_of_resource_hashes)"
    end
    if bad_resources?
      raise ArgumentError, "Resources passed to AppPackage must have relative filenames"
    end
  end

  # Collects the necessary files and returns the path to a finished zip file.
  # This needs to be called in a fiber context.
  # FIXME(dlc) - This needs to yield, or better yet be an EM.system call out
  def to_zip
    tmpdir = Dir.mktmpdir
    dir = path = nil
    timed_section(CloudController.logger, 'app_to_zip') do
      dir = unpack_upload
      synchronize_pool_with(dir)
      path = AppPackage.repack_app_in(dir, tmpdir, :zip)
      zip_path = save_package(path) if path
    end
  ensure
    FileUtils.rm_rf(tmpdir)
    FileUtils.rm_rf(dir) if dir
    FileUtils.rm_rf(File.dirname(path)) if path
  end

  # Repacks the working directory into a compressed file.
  # By default this uses zip format.
  def self.repack_app_in(dir, tmpdir, format)
    if format == :zip
      target_path = File.join(tmpdir, 'app.zip')
      cmd = "cd #{dir}; zip -q -y #{target_path} -r * 2>&1"
    else
      target_path = File.join(tmpdir, 'app.tgz')
      cmd = "cd #{dir}; COPYFILE_DISABLE=true tar -czf #{target_path} * 2>&1"
    end

    timed_section(CloudController.logger, 'repack_app') do
      AppPackage.blocking_defer do
        output = `#{cmd}`
        if $? != 0
          FileUtils.rm_rf(tmpdir)
          CloudController.logger.warn("Unable to repack application in #{dir}: #{output} #{$?}")
          raise AppPackageError, "Failed repacking application"
        end
      end
    end
    target_path
  end

  def self.package_dir
    @package_dir ||= begin
                       dir = AppConfig[:directories] && AppConfig[:directories][:droplets]
                       dir ||= Rails.root.join('tmp')
                       FileUtils.mkdir_p(dir) unless File.directory?(dir)
                       dir
                     end
  end

  # Yields the current fiber until the supplied block completes execution.
  # Propagates any exceptions raised inside the block back to the "calling"
  # fiber.
  def self.blocking_defer(&blk)
    f = Fiber.current

    # Executed in a thread reserved by EM for deferred ops
    deferred_proc = Proc.new do
      begin
        retval = blk.call
        [:success, retval]
      rescue => e
        [:error, e]
      end
    end

    # Executed on the main event loop
    callback = Proc.new {|result| f.resume(result) }

    EM.defer(deferred_proc, callback)

    status, retval = Fiber.yield
    if status == :success
      retval
    else
      raise retval
    end
  end

private

  def package_dir
    self.class.package_dir
  end

  def save_package(path)
    sha1 = Digest::SHA1.file(path).hexdigest
    new_path = File.join(package_dir, sha1)
    FileUtils.mv(path, new_path)
    new_path
  end

  def unpack_upload
    working_dir = Dir.mktmpdir
    if @uploaded_file
      cmd = "unzip -q -d #{working_dir} #{@uploaded_file.path}"
      f = Fiber.current
      EM.system(cmd) do |output, status|
        FileUtils.rm_rf(working_dir) if status.exitstatus != 0
        f.resume({:status => status, :output => output})
      end
      unzip_result = Fiber.yield
      if unzip_result[:status].exitstatus != 0
        CloudController.logger.error("'#{cmd}' exited with status #{unzip_result[:status].exitstatus}")
        CloudController.logger.error("Output: '#{unzip_result[:output]}'")
        raise AppPackageError, "Failed unzipping application"
      end
    end
    working_dir
  end

  # Do resource pool synch, needs to be called with a Fiber context
  def synchronize_pool_with(working_dir)
    timed_section(CloudController.logger, 'process_app_resources') do
      AppPackage.blocking_defer do
        pool = CloudController.resource_pool
        pool.add_directory(working_dir)
        @resource_descriptors.each do |descriptor|
          target = File.join(working_dir, descriptor[:fn])
          pool.copy(descriptor, target)
        end
      end
    end
  rescue => e
    CloudController.logger.error("Failed synchronizing resource pool with '#{working_dir}'")
    CloudController.logger.error(e)
    raise AppPackageError, "Failed synchronizing resource pool"
  end

  def bad_resources?
    @resource_descriptors.any? {|h| h[:fn].blank? || h[:fn].starts_with?('/')}
  end
end

