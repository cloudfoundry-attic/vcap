def log_exception(e)
  begin
    @logger.error "Exception Caught (#{e.class.name}): #{e.to_s}"
    @logger.error e
  rescue
    # Do nothing
  end
end

