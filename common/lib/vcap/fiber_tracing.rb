# Copyright (c) 2009-2011 VMware, Inc.
class Fiber
  attr_accessor :trace_id
  alias_method :orig_resume, :resume

  class << self
    @io=nil

    alias_method :orig_yield, :yield

    def enable_tracing(io)
      raise ArgumentError, "You must pass in IO object, #{io.class} given" unless io.is_a? IO
      @io = io
    end

    def yield(*args)
      log_action('yield')
      begin
        orig_yield(*args)
      rescue FiberError => fe
        Fiber.log_action('yield_error', self)
        raise fe
      end
    end

    def log_action(action, f=nil)
      return unless @io
      f ||= Fiber.current
      trace_id = f.trace_id || '-'
      cname = Kernel.caller[1]
      @io.puts("FT %-14s %-20s %-30s %s" % [action, trace_id, f.object_id, cname])
      @io.flush
    end
  end

  def resume(*args)
    Fiber.log_action('resume', self)
    begin
      orig_resume(*args)
    rescue FiberError => fe
      Fiber.log_action('resume_error', self)
      raise fe
    end
  end
end
