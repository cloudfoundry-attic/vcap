module Run
  class << self
    def run_cmd(cmd, expected_result = 0)
      cmd_str = "#{cmd} 2>&1"
      stdout = `#{cmd_str}`
      result = $?
      if result != expected_result
        raise "command #{cmd} failed with result #{status}, expected: #{expected_result}"
      end
      return stdout, result
    end
  end
end

