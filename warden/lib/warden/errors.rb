module Warden

  class WardenError < StandardError

    def message
      super || "unknown error"
    end
  end
end
