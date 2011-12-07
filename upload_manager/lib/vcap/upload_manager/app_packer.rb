require 'logger'
require 'tmpdir'
require 'vcap/subprocess'
require 'fileutils'

module VCAP module UploadManager end end

class VCAP::UploadManager::AppPacker
  def initialize(packer_root, resource_pool = nil, logger = nil)
    @logger = logger || Logger.new(STDOUT)
    @resource_pool = resource_pool
    @pack_dir = Dir.mktmpdir(nil, packer_root)
    @upload_id = nil
  end

  def valid_resource_list?(resource_list)
    #XXX add some sanity checks.
    true
  end

  def import_upload(id, upload_path, resource_list)
    raise "invalid resource list" unless valid_resource_list?(resource_list)
    @resource_list = resource_list
    raise "invalid path #{upload_path}" unless File.exists?(upload_path)
    @uploaded_file = File.join(@pack_dir, 'upload.zip')
    File.rename(upload_path, @uploaded_file)
    @upload_id = id
    @logger.debug "Imported upload #{id}."
  end

  def log_cmd_err(e)
    @logger.error("unpacker:#{e.to_s}:stdout:>> #{e.stdout} << :stderr >> #{e.stderr} <<")
  end

  def unpack_upload
    @expanded_dir = Dir.mktmpdir(nil, @pack_dir)
    @logger.debug "Unpacking app #{@upload_id}"
    #XXX add zip bomb protection.
    unzip_cmd = "unzip -q -d #{@expanded_dir} #{@uploaded_file}"
    begin
      VCAP::Subprocess.run(unzip_cmd)
    rescue => e
      log_cmd_err(e)
      raise "unzip failed for upload #{@upload_id}"
    end
  end

  # enforce property that any file in resource list must be located in the
  # apps directory e.g. '../../foo' or a symlink pointing outside working_dir
  # should raise an exception.
  def resolve_path(working_dir, tainted_path)
    expanded_dir  = File.realdirpath(working_dir)
    expanded_path = File.realdirpath(tainted_path, expanded_dir)
    pattern = "#{expanded_dir}/*"
    unless File.fnmatch?(pattern, expanded_path)
      raise ArgumentError, "Resource path sanity check failed #{pattern}:#{expanded_path}!!!!"
    end
    expanded_path
  end

  def sync_with_resource_pool
    @logger.debug("syncing upload #{@upload_id} with resource pool")
    @resource_pool.add_directory(@expanded_dir)
    @resource_list.each { |descriptor|
      path = resolve_path(@expanded_dir, descriptor[:fn])
      @resource_pool.retrieve_file(descriptor, path)
    }
  end

  def repack_app
    @packaged_app = File.join(@pack_dir, 'packaged_app.zip')
    @logger.debug "Repacking app #{@upload_id}"
    repack_cmd = "cd #{@expanded_dir}; zip -q -y #{@packaged_app} -r * 2>&1"
    begin
      VCAP::Subprocess.run(repack_cmd)
    rescue => e
      log_cmd_err(e)
      raise "zip failed for upload #{@upload_id}"
    end
  end

  def package_app
    unpack_upload
    sync_with_resource_pool
    repack_app
  end

  def get_package
    raise "No package available" unless File.exists? @packaged_app
    @packaged_app
  end

  def cleanup!
    FileUtils.rm_rf @pack_dir, :secure => true
  end

end
