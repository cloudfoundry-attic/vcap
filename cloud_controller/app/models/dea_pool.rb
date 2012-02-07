class DEAPool
  DEA_EXPIRATION_TIME = 10

  class << self
    def dea_list
      @dea_list ||= {}
    end

    def process_advertise_message(msg)
      CloudController.logger.debug("Got DEA advertisement#{msg}.")
      dea_list[msg[:id]] = {:msg => msg, :time => Time.now.to_i}
    end

     def find_dea(app)
       required_mem = app[:limits][:mem]
       required_runtime = app[:runtime]
       keys = dea_list.keys.shuffle
       keys.each do |key|
         entry = dea_list[key]
         dea = entry[:msg]
         last_update = entry[:time]
         if Time.now.to_i - last_update > DEA_EXPIRATION_TIME
           CloudController.logger.debug("DEA #{dea[:id]} expired from pool.")
           dea_list.delete(key)
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
