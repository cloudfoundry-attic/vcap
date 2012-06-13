require 'chef/mixin/checksum'
require 'chef/mixin/enforce_ownership_and_permissions'
require 'blobstore_client'

include Bosh::Blobstore
include Chef::Mixin::Checksum

BLOBSTORE_HOST = {
  :url => "https://blob.cfblob.com",
  :uid => "bb6a0c89ef4048a8a0f814e25385d1c5/user1"
}

def load_current_resource
  @current_resource = @new_resource.class.new(@new_resource.name)
  if @current_resource.path.exist?
    @current_resource.checksum(checksum(@current_resource.path.to_s))
  end
end

def download_blob(id)
  Tempfile.open('cf-temp') do |tf|
    AtmosBlobstoreClient.new(BLOBSTORE_HOST).get_file(id, tf)
    tf.close
    yield tf.path
  end
end

def action_create
  unless @new_resource.path.dirname.directory?
    raise "Cannot create file under #{@new_resource.path.dirname}, check if it refers to a real directory"
  end

  Chef::Log.debug("#{@new_resource} checking for changes")

  if @current_resource.path.exist? && @current_resource.checksum == @new_resource.checksum
    Chef::Log.debug("#{@new_resource} checksum matches target checksum (#{@new_resource.checksum}) - not updating")
  else
    download_blob(@new_resource.id) do |tempfile|
      Chef::Log.debug "#{@new_resource} has checksum set to: #{@new_resource.checksum}, checking remote file checksum"
      remote_file_checksum = checksum(tempfile)
      if remote_file_checksum == @new_resource.checksum
        Chef::Log.debug "remote file checksum: #{remote_file_checksum}, validated!"
        FileUtils.cp(tempfile, @new_resource.path)
        Chef::Log.info "#{@new_resource} updated"
        @new_resource.updated_by_last_action(true)
      else
        Chef::Log.debug "remote file checksum: #{remote_file_checksum}, invalid"
        # TODO: retry?
        raise "Checksum mismatch for cf_remote_file #{@new_resource}"
      end
    end
  end

  enforce_ownership_and_permissions
  @new_resource.updated_by_last_action?
end
