require 'fileutils'
require 'rest_client'
require 'uri'


module VCAP
  module Stager
  end
end

module VCAP::Stager::Util
  class << self
    # Downloads the zipped app living at _app_uri_ and stores it in a temporary file.
    #
    # NB: This streams the file to disk.
    #
    # @param   app_uri    String   Uri where one can fetch the app. Credentials should be included
    #                              in the uri (i.e. 'http://user:pass@www.foo.com/bar.zip')
    # @param   dest_path  String   When the app should be saved on disk
    #
    # @return  Net::HTTPResponse
    def fetch_zipped_app(app_uri, dest_path)
      save_app = proc do |resp|
        unless resp.kind_of?(Net::HTTPSuccess)
          raise VCAP::Stager::AppDownloadError,
                "Non 200 status code (#{resp.code})"
        end

        begin
          File.open(dest_path, 'w+') do |f|
            resp.read_body do |chunk|
              f.write(chunk)
            end
          end
        rescue => e
          FileUtils.rm_f(dest_path)
          raise e
        end

        resp
      end

      req = RestClient::Request.new(:url => app_uri,
                                    :method => :get,
                                    :block_response => save_app)
      req.execute
    end

    # Uploads the file living at _droplet_path_ to the uri using a PUT request.
    #
    # NB: This streams the file off of disk in 1k chunks.
    #
    # @param  uri           String  Where the app should be uploaded to
    # @param  droplet_path  String  The location on disk of the droplet to be uploaded
    #
    # @return Net::HTTPResponse
    def upload_droplet(droplet_uri, droplet_path)
      RestClient.post(droplet_uri,
                      :upload => {
                        :droplet => File.new(droplet_path, 'rb')
                      })
    end
  end
end
