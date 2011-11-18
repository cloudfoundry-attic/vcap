require "warden/container/script_handler"

module Warden

  module Container

    class RemoteScriptHandler < ScriptHandler

      def unbind
        if buffer.empty?
          # The wrapper script was terminated before it could return anything.
          # It is likely that the container was destroyed while the script
          # was being executed.
          set_deferred_failure "execution aborted"
        else
          status, path = buffer.chomp.split
          stdout_path = File.join(path, "stdout") if path
          stderr_path = File.join(path, "stderr") if path
          set_deferred_success [status.to_i, stdout_path, stderr_path]
        end
      end
    end
  end
end
