require "sinatra/base"

# Simple handler that serves zipped apps from the fixtures directory and
# handles uploads by storing the request body in a user supplied hash
class DummyHandler < Sinatra::Base
  def self.app_download_uri(http_server, app_name)
    "http://foo:sekret@127.0.0.1:#{http_server.port}/zipped_apps/#{app_name}"
  end

  def self.droplet_upload_uri(http_server, app_name)
    "http://foo:sekret@127.0.0.1:#{http_server.port}/droplets/#{app_name}"
  end

  use Rack::Auth::Basic do |user, pass|
    user == 'foo' && pass = 'sekret'
  end

  get '/zipped_apps/:name' do
    app_zip_path = File.join(settings.download_path, "#{params[:name]}.zip")
    if File.exist?(app_zip_path)
      File.read(app_zip_path)
    else
      [404, ":("]
    end
  end

  post '/droplets/:name' do
    dest_path = File.join(settings.upload_path, params[:name] + '.tgz')
    File.open(dest_path, 'w+') {|f| f.write(params[:upload][:droplet]) }
    [200, "Success!"]
  end

  get '/fail' do
    [500, "Oh noes"]
  end
end
