class DEAPool
  DEA_PROFILE_EXPIRATION_TIME = 10

  class << self
    def dea_profiles
      @dea_profiles ||= {}
    end

    def process_advertise_message(msg)
      CloudController.logger.debug2("Got DEA advertisement#{msg}.")
      dea_profiles[msg[:id]] = {:profile => msg, :time => Time.now.to_i}
    end

     def find_dea(app)
       required_mem = app[:limits][:mem]
       required_runtime = app[:runtime]
       keys = dea_profiles.keys.shuffle
       keys.each do |key|
         entry = dea_profiles[key]
         dea = entry[:profile]
         last_update = entry[:time]
         if Time.now.to_i - last_update > DEA_PROFILE_EXPIRATION_TIME
           CloudController.logger.debug("DEA #{dea[:id]} expired from pool.")
           dea_profiles.delete(key)
           next
         end

         if (dea[:available_memory] >= required_mem) && (dea[:runtimes].member? required_runtime)
           CloudController.logger.debug("Found DEA #{dea[:id]}.")
           return dea[:id]
         end
       end
       nil
     end
  end
end
