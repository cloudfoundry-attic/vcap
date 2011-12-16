#wrap code that needs a fiber pool/reactor to run but doesn't have one
#yet e.g. for startup and testing.
require 'fiber'
require 'eventmachine'
def em_fiber_wrap
  EventMachine.run {
      Fiber.new {
      yield
      EventMachine.stop
      }.resume
    }
end


