module Warden

  module Network

    class Octets

      attr_reader :v

      include Comparable

      def <=>(other)
        v <=> Octets.new(other).v
      end

      def eql?(other)
        v == Octets.new(other).v
      end

      def hash
        v.hash
      end

      def initialize(v, *args)
        if args.empty?
          if v.kind_of?(Fixnum)
            @v = v
          elsif v.kind_of?(Octets)
            @v = v.v
          elsif v.kind_of?(String)
            if m = v.match(/[0-9a-f]{8}/)
              @v = v.to_i(16)
            else
              @v = to_integer(v.split("."))
            end
          else
            raise "invalid value"
          end
        else
          @v = to_integer([v] + args)
        end

        raise "invalid address" if @v != (@v & (2 ** 32 - 1))
      end

      def to_octets
        [(v >> 24) & 255, (v >> 16) & 255, (v >> 8) & 255, (v >> 0) & 255]
      end

      def to_hex
        to_octets.map { |e| "%02x" % e }.join
      end

      def to_human
        to_octets.join(".")
      end

      protected

      def to_integer(octets)
        octets.inject(0) { |a,e| a * 256 + e.to_i }
      end
    end

    class Netmask < Octets

      def initialize(*args)
        super
        raise "invalid netmask" unless valid?
      end

      def size
        (~v & (2 ** 32 - 1)) + 1
      end

      protected

      # Netmask size should be a power of 2
      def valid?
        ((size - 1) & size) == 0
      end
    end

    class Address < Octets

      def network(netmask)
        Address.new(v & netmask.v)
      end

      def +(other)
        case other
        when Fixnum
          Address.new(v + other)
        when Netmask
          Address.new(v + other.size)
        else
          raise "cannot add #{other.class}"
        end
      end
    end
  end
end
