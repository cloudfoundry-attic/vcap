# This is a Fiber (1.9) aware extension.
module NATS
  class << self
    def timed_request(subject, data=nil, opts = {})
      expected = opts[:expected] || 1
      timeout  = opts[:timeout]  || 1
      f = Fiber.current
      results = []
      sid = NATS.request(subject, data, :max => expected) do |msg|
        results << msg
        f.resume if results.length >= expected
      end
      NATS.timeout(sid, timeout, :expected => expected) { f.resume }
      Fiber.yield
      NATS.unsubscribe(sid) # memory leak fix; this line can be removed after using a fixed version of nats client(> 0.4.22.beta.4)
      return results.slice(0, expected)
    end
  end
end
