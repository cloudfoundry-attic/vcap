require 'fileutils'
require 'logger'
require 'digest/sha1'
require 'vcap/em_run'

module VCAP module PackageCache end end

class VCAP::PackageCache::Inbox
  def initialize(inbox_root, type, logger = nil)
    @logger = logger || Logger.new(STDOUT)
    raise "Invalid inbox root #{inbox_root}" if not Dir.exists? inbox_root
    if type == :server
      setup_inbox_dirs(inbox_root)
    elsif type == :client
      @inbox_public = File.join(inbox_root, 'public')
      raise "Invalid public inbox" unless Dir.exists? @inbox_public
    else
      raise "Invalid inbox type #{type.to_s}"
    end
  end

  def setup_inbox_dirs(inbox_root)
    @inbox_root = inbox_root
    @inbox_public = File.join(inbox_root, 'public')
    FileUtils.mkdir_p(@inbox_public)
    set_public_inbox_permissions(@inbox_public)
    @inbox_private = File.join(inbox_root,'private')
    FileUtils.mkdir_p(@inbox_private)
    #only the package_cache user should be able to access the private inbox.
    File.chmod(0700, @inbox_private)
  end

  # ==Public inbox access control model ==
  #-users can add/remove their own entries (but not those of others).
  #-users cannot list what else is in the inbox (have to access things by known name).
  #
  #file mask has two parts
  #01000 - sets the sticky bit, preventing users from overwriting the
  #        files of other users.
  #00733 - allows users to add/remove files but not list the directory.
  def set_public_inbox_permissions(dir)
    File.chmod(01733, dir)
  end

  def get_private_entry(name)
    path = File.join @inbox_private, name
    raise "no inbox entry #{name} found" if not File.exists?(path)
    path
  end

  def verify_file_hash(name, path)
    name_hash,_ = File.basename(name,'.*')
    content_hash = Digest::SHA1.file(path).hexdigest
    content_hash == name_hash
  end

  def secure_import_entry(name)
    @logger.info("importing inbox entry #{name}.")
    src_path =  File.join @inbox_public, name
    dst_path =  File.join @inbox_private, name
    tmp_file = random_file_name(:suffix => '.unverified')
    tmp_path = File.join @inbox_private, tmp_file
    raise "no file #{name} in public inbox" unless File.exists? src_path

    #copy source to tmp file and verify its legit.
    FileUtils.mv src_path, tmp_path
    raise "File hash invalid." if not verify_file_hash(name, tmp_path)
    File.rename(tmp_path, dst_path)
  end

  def private_contains?(name)
    File.exists?(File.join(@inbox_private, name))
  end

  def purge!
    @logger.info("purging inbox directory #{@inbox_root}")
    FileUtils.rm_f Dir.glob("#{@inbox_root}/*/*")
  end

  #client interface

  def public_contains?(name)
    File.exists?(File.join(@inbox_public, name))
  end

  def file_to_entry_name(path)
    content_hash = Digest::SHA1.file(path).hexdigest
    extension = File.extname(path)
    entry_name = "#{content_hash}#{extension}"
  end

  def add_entry(src_path)
    entry_name = file_to_entry_name(src_path)
    if public_contains?(entry_name)
      raise "file named #{entry_name} already in inbox"
    end
    @logger.debug("adding #{src_path} to inbox as #{entry_name}")
    FileUtils.cp src_path, File.join(@inbox_public, entry_name)
    entry_name
  end

  private

  def random_file_name(opts={})
    opts = {:chars => ('0'..'9').to_a + ('A'..'F').to_a + ('a'..'f').to_a,
            :length => 16, :prefix => '', :suffix => '',
            :verify => true, :attempts => 10}.merge(opts)
    opts[:attempts].times do
      filename = ''
      opts[:length].times do
        filename << opts[:chars][rand(opts[:chars].size)]
      end
      filename = opts[:prefix] + filename + opts[:suffix]
      return filename unless opts[:verify] && File.exists?(filename)
    end
    raise "random file creation failed!!!"
  end

end
