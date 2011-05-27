require "monitor"

module VCAP

  class RollingMetric

    def initialize(duration, num_buckets = 60)
      @duration = duration
      num_buckets = [@duration, num_buckets].min
      @bucket_duration = (@duration / num_buckets).to_i
      @eviction_duration = @bucket_duration * 2
      @buckets = []
      num_buckets.times do
        @buckets << {:timestamp => 0, :value => 0, :samples => 0}
      end
    end

    def <<(value)
      timestamp = Time.now.to_i
      bucket = @buckets[(timestamp / @bucket_duration) % @buckets.length]
      if timestamp - bucket[:timestamp] > @eviction_duration
        bucket[:timestamp] = timestamp
        bucket[:value] = value
        bucket[:samples] = 1
      else
        bucket[:value] += value
        bucket[:samples] += 1
      end
    end

    def value
      timestamp = Time.now.to_i
      min_timestamp = timestamp - @duration

      value = 0
      samples = 0

      @buckets.each do |bucket|
        if bucket[:timestamp] > min_timestamp
          value += bucket[:value]
          samples += bucket[:samples]
        end
      end

      {
        :value => value,
        :samples => samples
      }
    end

    def to_json
      Yajl::Encoder.encode(value)
    end

  end

  class ThreadSafeRollingMetric < RollingMetric

    def initialize(*args)
      super(*args)
      @lock = Monitor.new
    end

    def <<(*args)
      @lock.synchronize { super(*args) }
    end

    def value(*args)
      @lock.synchronize { super(*args) }
    end

  end

end
