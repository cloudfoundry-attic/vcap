module VCAP
  module Blobstore

    class BlobstoreError < StandardError; end
    class NotFound < BlobstoreError; end
  end
end
