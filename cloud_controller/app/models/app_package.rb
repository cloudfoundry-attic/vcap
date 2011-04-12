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
    timed_section(Rails.logger, 'app_to_zip') do
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
      cmd = "cd #{dir}; zip -q -y #{target_path} -r *"
    else
      target_path = File.join(tmpdir, 'app.tgz')
      cmd = "cd #{dir}; COPYFILE_DISABLE=true tar -czf #{target_path} *"
    end

    timed_section(Rails.logger, 'repack_app') do
      f = Fiber.current
      opts = {
        :logger => Rails.logger,
        :nobacktrace => true,
        :callback => proc { f.resume }
      }
      VCAP.defer(opts) do
        output = `#{cmd}`
        if $? != 0
          target_path = nil
          FileUtils.rm_rf(tmpdir)
          Rails.logger.warn("Unable to repack application in #{dir}: #{output} #{$?}")
        end
      end
      Fiber.yield
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
      EM.system(cmd) { |output, status|
        if status.exitstatus != 0
          FileUtils.rm_rf(working_dir)
          working_dir = nil
        end
        f.resume
      }
      Fiber.yield
    end
    raise "Unable to unpack upload from #{@uploaded_file.path}" if working_dir.nil?
    working_dir
  end

  # Do resource pool synch, needs to be called with a Fiber context
  def synchronize_pool_with(working_dir)
    timed_section(Rails.logger, 'process_app_resources') do
      f = Fiber.current
      opts = {
        :logger => Rails.logger,
        :nobacktrace => true,
        :callback => proc { f.resume }
      }
      VCAP.defer(opts) do
        pool = CloudController.resource_pool
        pool.add_directory(working_dir)
        @resource_descriptors.each do |descriptor|
          target = File.join(working_dir, descriptor[:fn])
          pool.copy(descriptor, target)
        end
      end
      Fiber.yield
    end
  end

  def bad_resources?
    @resource_descriptors.any? {|h| h[:fn].blank? || h[:fn].starts_with?('/')}
  end
end

