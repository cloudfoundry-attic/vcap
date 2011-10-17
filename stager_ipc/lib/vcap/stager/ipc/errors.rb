module VCAP
  module Stager
    module Ipc
      class IpcError < StandardError; end

      class EncodeError < IpcError; end
      class DecodeError < IpcError; end

      class RequestTimeoutError < IpcError; end
    end
  end
end
