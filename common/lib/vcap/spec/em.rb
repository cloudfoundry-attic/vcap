# Copyright (c) 2009-2011 VMware, Inc.
module VCAP

  module Spec

    module EM

      def em(options = {})
        raise "no block given" unless block_given?
        timeout = options[:timeout] ||= 1.0

        ::EM.run {
          quantum = 0.005
          ::EM.set_quantum(quantum * 1000) # Lowest possible timer resolution
          ::EM.set_heartbeat_interval(quantum) # Timeout connections asap
          ::EM.add_timer(timeout) { raise "timeout" }
          yield
        }
      end

      def done
        raise "reactor not running" if !::EM.reactor_running?

        ::EM.next_tick {
          # Assert something to show a spec-pass
          :done.should == :done
          ::EM.stop_event_loop
        }
      end
    end
  end
end
