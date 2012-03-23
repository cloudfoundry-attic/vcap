require "warden/network"

module Warden

  module Pool

    class NetworkPool

      attr_reader :netmask

      # The release delay can be used to postpone address being acquired again
      # after being released. This can be used to make sure the kernel has time
      # to clean up things such as lingering connections.

      def initialize(start_address, count, options = {})
        @start_address = Warden::Network::Address.new(start_address)
        @netmask = Network::Netmask.new(255, 255, 255, 252)
        @pool = count.times.map { |i|
          [Time.mktime(1970), @start_address + @netmask.size * i]
        }

        @release_delay = options[:release_delay] || 5
      end

      def acquire
        time, address = @pool.first

        if time && time < Time.now
          @pool.shift
          return address
        end

        return nil
      end

      def release(address)
        @pool.push [Time.now + @release_delay, address]
      end
    end
  end
end
