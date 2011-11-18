require "hiredis"

shared_context :warden_client do

  def create_client
    client = Hiredis::Connection.new
    client.connect_unix(unix_domain_path)

    def client.read
      reply = super
      raise reply if reply.kind_of?(StandardError)
      reply
    end

    def client.call(*args)
      write(args)
      read
    end

    client
  end
end
