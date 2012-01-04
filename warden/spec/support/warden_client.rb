require "warden/client"

shared_context :warden_client do

  def create_client
    client = ::Warden::Client.new(unix_domain_path)
    client.connect
    client
  end
end
