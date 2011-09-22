require 'fiber'

class FiberMutex

  def initialize
    @holder = nil
    @queue = []
  end

  def lock
    if !@holder
      @holder = Fiber.current
    elsif @holder == Fiber.current
      raise Error
    else
      @queue << Fiber.current
      Fiber.yield
    end
  end

  def unlock
    @holder = @queue.shift
    EM.next_tick do
      @holder.resume if @holder
    end
  end

end
