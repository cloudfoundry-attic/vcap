require 'socket'

module CloudFoundry
  def cf_bundle_install(path)
    bash "Bundle install for #{path}" do
      cwd path
      user node[:deployment][:user]
      code "#{File.join(node[:ruby][:path], "bin", "bundle")} install"
      only_if { ::File.exist?(File.join(path, 'Gemfile')) }
    end
  end

  A_ROOT_SERVER = '198.41.0.4'
  def cf_local_ip(route = A_ROOT_SERVER)
    route ||= A_ROOT_SERVER
    orig, Socket.do_not_reverse_lookup = Socket.do_not_reverse_lookup, true
    UDPSocket.open {|s| s.connect(route, 1); s.addr.last }
  ensure
    Socket.do_not_reverse_lookup = orig
  end
end

class Chef::Recipe
  include CloudFoundry
end

# Monkey-patch RemoteFile to suppress decompression of gzip
require 'chef/provider/file'
class Chef::Provider::RemoteFile
  require 'net/http'

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
    assert_enclosing_directory_exists!

    Chef::Log.debug("#{@new_resource} checking for changes")

    if current_resource_matches_target_checksum?
      Chef::Log.debug("#{@new_resource} checksum matches target checksum (#{@new_resource.checksum}) - not updating")
    else
      uri = URI(@new_resource.source)
      stream_to_tempfile(uri) do |tempfile|
        # new download should be rejected if checksum is invalid
        if @new_resource.checksum
          Chef::Log.debug "#{@new_resource} has checksum set to: #{@new_resource.checksum}, checking remote file checksum"
          c = checksum(tempfile)
          if c.include? @new_resource.checksum
            Chef::Log.debug "remote file checksum: #{c}, validated!"
            FileUtils.cp(tempfile, @new_resource.path)
            Chef::Log.info "#{@new_resource} updated"
            @new_resource.updated_by_last_action(true)
          else
            Chef::Log.debug "remote file checksum: #{c}, invalid"
            # TODO: retry?
            raise "Checksum mismatch for remote_file #{@new_resource}"
          end
        else
          if matches_current_checksum?(tempfile)
            Chef::Log.debug "#{@new_resource} target and source checksums are the same - not updating"
          else
            backup_new_resource
            FileUtils.cp raw_file.path, @new_resource.path
            Chef::Log.info "#{@new_resource} updated"
            @new_resource.updated_by_last_action(true)
          end
        end
      end
    end

    enforce_ownership_and_permissions

    @new_resource.updated_by_last_action?
  end
end
