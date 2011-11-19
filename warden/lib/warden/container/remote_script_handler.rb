require "warden/container/script_handler"

module Warden

  module Container

    class RemoteScriptHandler < ScriptHandler

      # This handler is only interesting in knowning when the descriptor was
      # closed. Success/failure is determined by other logic.
      def unbind
        set_deferred_success
      end
    end
  end
end
