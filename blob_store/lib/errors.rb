module VCAP
  module BlobStore

    class BlobStoreError < StandardError; end
    class NotFound < BlobStoreError; end
  end
end
