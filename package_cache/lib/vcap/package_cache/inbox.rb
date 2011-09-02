$:.unshift(File.join(File.dirname(__FILE__),'../../common/lib'))
$:.unshift(File.join(File.dirname(__FILE__)))
require 'logger'
require 'lib/vdebug'
require 'digest/sha1'
require 'vcap/subprocess'
require 'lib/emrun'

module VCAP module PackageCache end end

class VCAP::PackageCache::Inbox
  def initialize(inbox_dir, type, logger = nil)
    @logger = logger || Logger.new(STDOUT)
    if Dir.exists? inbox_dir
      @inbox_dir = inbox_dir
    else
      raise "Invalid inbox_dir #{inbox_dir} for Inbox type #{type}"
    end
    if type == :server
      set_inbox_permissions
    elsif type != :client
      raise "Invalid inbox type #{type.to_s}"
    end
  end

  def get_entry(name)
    path = get_entry_path(name)
    raise "no inbox entry #{name} found" if not File.exists?(path)
    path
  end

  def secure_import_entry(name)
    raise "no file #{name} in inbox" if not contains?(name)

    #1. ensure no one can open this file except the package cache.
    set_entry_permissions(name)

    #2. ensure no one is holding an existing file descriptor.
    raise "file in use, cannot be imported" if not verify_no_file_users(name)

    #3. if both these hold and the content checks out, we are good.
    raise "entry hash does not match contents!" if not verify_entry_hash(name)
    @logger.info("importing inbox entry #{name}.")
  end

  def contains?(name)
    File.exists? get_entry_path(name)
  end

  def file_to_entry_name(path)
    content_hash = Digest::SHA1.file(path).hexdigest
    extension = File.extname(path)
    entry_name = "#{content_hash}#{extension}"
  end

  def add_entry(src_path)
    entry_name = file_to_entry_name(src_path)
    if contains?(entry_name)
      raise "file named #{entry_name} already in inbox"
    end
    @logger.debug("adding #{src_path} to inbox as #{entry_name}")
    FileUtils.cp src_path, File.join(@inbox_dir, entry_name)
    entry_name
  end

  def purge!
    @logger.info("purging inbox directory #{@inbox_dir}")
    FileUtils.rm_f Dir.glob("#{@inbox_dir}/*")
  end

  private

  def get_entry_path(name)
    File.join(@inbox_dir, name)
  end

  def set_entry_permissions(name)
    path = get_entry_path(name)
    File.chown(Process.uid, Process.gid, path)
    #when we import an entry, deny anyone but the cache access to it.
    File.chmod(0700, path)
  end

  # ==Inbox access control model ==
  #-users can add/remove their own entries (but not those of others).
  #-users cannot list what else is in the inbox (have to access things by known name).
  #
  #file mask has two parts
  #01000 - sets the sticky bit, preventing users from overwriting the
  #        files of other users.
  #00733 - allows users to add/remove files but not list the directory.
  def set_inbox_permissions
    File.chown(Process.uid, Process.gid, @inbox_dir)
    File.chmod(01733, @inbox_dir)
  end

  def verify_entry_hash(name)
    path = get_entry_path(name)
    name_hash,_ = File.basename(name,'.*')
    content_hash = Digest::SHA1.file(path).hexdigest
    content_hash == name_hash
  end

  def verify_no_file_users(name)
    path = get_entry_path(name)
    output, status = VCAP::EMRun.run("fuser #{path}", 1)
    if status != 1
      @logger.error("Security badness: file #{path} is in use by: #{output}, not safe to import!!")
      return false
    end
    true
  end
end
