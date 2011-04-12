class Object
  def timed_section(logger, name = nil)
    # If no name is given, try to give a useful description.
    name ||= caller.first.split(':').last
    start_time = Time.now
    ret = yield
    if logger
      logger.debug "[#{name}] took #{Time.now - start_time} seconds to execute."
    end
    ret
  end
end

