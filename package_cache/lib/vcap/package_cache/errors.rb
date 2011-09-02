module VCAP
  module PackageCache
    class PackageCacheError < StandardError;    end
    class ClientError      < PackageCacheError; end
    class ServerError      < PackageCacheError; end
  end
end
