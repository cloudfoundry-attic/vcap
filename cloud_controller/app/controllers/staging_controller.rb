require 'uri'

# Handles app downloads and droplet uploads from the stagers.
#
class StagingController < ApplicationController
  skip_before_filter :fetch_user_from_token
  before_filter :authenticate_stager

  # Handles a droplet upload from a stager
  def upload_droplet
    task = nil
    src_path = nil
    app = App.find_by_id(params[:id])
    raise CloudError.new(CloudError::APP_NOT_FOUND) unless app

    task = StagingTask.find_task(params[:staging_task_id])
    unless task
      CloudController.logger.error("No task associated with id #{params[:staging_task_id]}")
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
      CloudController.logger.debug("Renaming staged droplet from '#{src_path}' to '#{task.upload_path}'")
      File.rename(src_path, task.upload_path)
    rescue => e
      CloudController.logger.error("Failed uploading staged droplet: #{e}", :tags => [:staging])
      CloudController.logger.error(e)
      FileUtils.rm_f(task.upload_path)
      raise e
    end
    CloudController.logger.debug("Stager (#{request.remote_ip}) uploaded droplet to #{task.upload_path}", :tags => [:staging])
    render :nothing => true, :status => 200
  ensure
    FileUtils.rm_f(src_path) if src_path
  end

  # Handles an app download from a stager
  def download_app
    app = App.find_by_id(params[:id])
    raise CloudError.new(CloudError::APP_NOT_FOUND) unless app

    path = app.unstaged_package_path
    unless path && File.exists?(path)
      CloudController.logger.error("Couldn't find package path for app_id=#{app.id} (stager=#{request.remote_ip})", :tags => [:staging])
      raise CloudError.new(CloudError::APP_NOT_FOUND)
    end
    CloudController.logger.debug("Stager (#{request.remote_ip}) requested app_id=#{app.id} @ path=#{path}", :tags => [:staging])

    if path && File.exists?(path)
      if CloudController.use_nginx
        response.headers['X-Accel-Redirect'] = '/droplets/' + File.basename(path)
        render :nothing => true, :status => 200
      else
        send_file path
      end
    else
      raise CloudError.new(CloudError::APP_NOT_FOUND)
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
