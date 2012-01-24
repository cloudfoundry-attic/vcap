module VCAP
  module PackageCacheClient
    class PackageCacheClientError < StandardError;    end
    class ClientError      < PackageCacheClientError; end
    class ServerError      < PackageCacheClientError; end
  end
end
