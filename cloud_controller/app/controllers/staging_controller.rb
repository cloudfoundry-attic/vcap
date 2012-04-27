require 'uri'

# Handles app downloads and droplet uploads from the stagers.
#
class StagingController < ApplicationController
  skip_before_filter :fetch_user_from_token
  before_filter :authenticate_stager

  class DropletUploadHandle
    attr_reader :upload_id, :upload_path, :upload_uri, :app

    def initialize(app)
      @app         = app
      @upload_id   = VCAP.secure_uuid
      @upload_path = File.join(AppConfig[:directories][:tmpdir],
                               "staged_upload_#{app.id}_#{@upload_id}.tgz")
      @upload_uri  = StagingController.upload_droplet_uri(app, @upload_id)
    end
  end

  class << self
    def upload_droplet_uri(app, upload_id)
      staging_uri("/staging/droplet/#{app.id}/#{upload_id}")
    end

    def download_app_uri(app)
      staging_uri("/staging/app/#{app.id}")
    end

    def create_upload(app)
      @uploads ||= {}
      ret = DropletUploadHandle.new(app)
      @uploads[ret.upload_id] = ret
      ret
    end

    def lookup_upload(upload_id)
      @uploads ||= {}
      @uploads[upload_id]
    end

    def complete_upload(handle)
      return unless @uploads
      @uploads.delete(handle.upload_id)
    end

    private

    def staging_uri(path)
      uri = URI::HTTP.build(
        :host     => CloudController.bind_address,
        :port     => CloudController.external_port,
        :userinfo => [AppConfig[:staging][:auth][:user], AppConfig[:staging][:auth][:password]],
        :path     => path
      )
      uri.to_s
    end
  end

  # Handles a droplet upload from a stager
  def upload_droplet
    upload = nil
    src_path = nil
    app = App.find_by_id(params[:id])
    raise CloudError.new(CloudError::APP_NOT_FOUND) unless app

    upload = self.class.lookup_upload(params[:upload_id])
    unless upload
      CloudController.logger.error("No upload set for upload_id=#{params[:upload_id]}")
      raise CloudError.new(CloudError::BAD_REQUEST)
    end

    if CloudController.use_nginx
      src_path = params[:droplet_path]
    else
      src_path = params[:upload][:droplet].path
    end
    unless src_path && File.exist?(src_path)
      CloudController.logger.error("Uploaded droplet not found at '#{src_path}'")
      raise CloudError.new(CloudError::BAD_REQUEST)
    end

    begin
      CloudController.logger.debug("Renaming staged droplet from '#{src_path}' to '#{upload.upload_path}'")
      File.rename(src_path, upload.upload_path)
    rescue => e
      CloudController.logger.error("Failed uploading staged droplet: #{e}", :tags => [:staging])
      CloudController.logger.error(e)
      FileUtils.rm_f(upload.upload_path)
      raise e
    end
    CloudController.logger.debug("Stager (#{request.remote_ip}) uploaded droplet to #{upload.upload_path}",
                                 :tags => [:staging])
    render :nothing => true, :status => 200
  ensure
    FileUtils.rm_f(src_path) if src_path
    self.class.complete_upload(upload) if upload
  end

  # Handles an app download from a stager
  def download_app
    app = App.find_by_id(params[:id])
    raise CloudError.new(CloudError::APP_NOT_FOUND) unless app

    unless path = app.unstaged_package_path
      CloudController.logger.error("app_id=#{app.id} has no package")
      raise CloudError.new(CloudError::APP_NOT_FOUND)
    end

    unless found = File.exist?(path)
      # Handle the case where the app exists at the old location: the sha1
      # of its zipfile.
      path = app.legacy_unstaged_package_path
      found = File.exist?(path)
    end

    unless found
      CloudController.logger.error("Couldn't find package path for app_id=#{app.id} (stager=#{request.remote_ip})", :tags => [:staging])
      raise CloudError.new(CloudError::APP_NOT_FOUND)
    end

    CloudController.logger.debug("Stager (#{request.remote_ip}) requested app_id=#{app.id} @ path=#{path}", :tags => [:staging])

    if CloudController.use_nginx
      response.headers['X-Accel-Redirect'] = '/droplets/' + File.basename(path)
      render :nothing => true, :status => 200
    else
      send_file path
    end
  end

  private

  def authenticate_stager
    authenticate_or_request_with_http_basic do |user, pass|
      if (user == AppConfig[:staging][:auth][:user]) && (pass == AppConfig[:staging][:auth][:password])
        true
      else
        CloudController.logger.error("Stager auth failed (user=#{user}, pass=#{pass} from #{request.remote_ip}", :tags => [:auth_failure, :staging])
        false
      end
    end
  end

end
