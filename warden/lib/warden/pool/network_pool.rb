require "warden/network"

module Warden

  module Pool

    class NetworkPool

      attr_reader :netmask

      def initialize(start_address, count)
        @netmask = Network::Netmask.new(255, 255, 255, 252)
        @pool = count.times.map { |i|
          start_address + @netmask.size * i
        }
      end

      def acquire
        @pool.shift
      end

      def release(address)
        @pool.push address
      end
    end
  end
end
