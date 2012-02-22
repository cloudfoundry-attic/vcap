# This patches an issue identified in mysql2 where an exception thrown down at the
# database level can kill the fiber, but mysql2 will try to resume it, causing the
# app to crash.
#
# Report here: https://github.com/brianmario/mysql2/issues/188
#
# Fiber support was moved to em-sychrony, however CF is on an older eventmachine
# that won't support em-sychrony, and don't need to add another dependency.
#
# A patch was provided in the big that this is based on:
#   https://gist.github.com/1058768
module Mysql2
  module Fibered
    class Client < ::Mysql2::Client
      def query(sql, opts={})
        if ::EM.reactor_running?
          super(sql, opts.merge(:async => true))
          deferrable = ::EM::DefaultDeferrable.new
          ::EM.watch(self.socket, Watcher, self, deferrable).notify_readable = true
          fiber = Fiber.current
          deferrable.callback do |result|
            # Make sure fiber is still alive
            fiber.resume(result) if fiber.alive?
          end
          deferrable.errback do |err|
            # Make sure fiber is still alive
            fiber.resume(err) if fiber.alive?
          end
          Fiber.yield.tap do |result|
            raise result if result.is_a?(Exception)
          end
        else
          super(sql, opts)
        end
      end
    end
  end
end
