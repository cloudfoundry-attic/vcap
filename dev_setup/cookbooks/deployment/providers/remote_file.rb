require 'chef/mixin/checksum'
require 'chef/mixin/enforce_ownership_and_permissions'

include Chef::Mixin::Checksum

require 'net/http'

def load_current_resource
  @current_resource = @new_resource.class.new(@new_resource.name)
  if @current_resource.path.exist?
    @current_resource.checksum(checksum(@current_resource.path.to_s))
  end
end

def stream_to_tempfile(uri)
  Net::HTTP.start(uri.host, uri.port) do |http|
    http.request_get(uri.path) do |response|
      Tempfile.open('cf-temp') do |tf|
        response.read_body {|chunk| tf.write(chunk) }
        tf.close
        yield tf.path
      end
    end
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
    uri = URI(@new_resource.source)
    stream_to_tempfile(uri) do |tempfile|
      # new download should be rejected if checksum is invalid
      Chef::Log.debug "#{@new_resource} has checksum set to: #{@new_resource.checksum}, checking remote file checksum"
      c = checksum(tempfile)
      if c == @new_resource.checksum
        Chef::Log.debug "remote file checksum: #{c}, validated!"
        FileUtils.cp(tempfile, @new_resource.path)
        Chef::Log.info "#{@new_resource} updated"
        @new_resource.updated_by_last_action(true)
      else
        Chef::Log.debug "remote file checksum: #{c}, invalid"
        # TODO: retry?
        raise "Checksum mismatch for cf_remote_file #{@new_resource}"
      end
    end
  end

  enforce_ownership_and_permissions
  @new_resource.updated_by_last_action?
end
