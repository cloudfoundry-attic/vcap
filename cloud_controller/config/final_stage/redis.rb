if AppConfig[:redis]
  EM::Hiredis.logger = CloudController.logger

  # This will be run once the event loop has started
  EM.next_tick do
    redis_client = EM::Hiredis::Client.new(AppConfig[:redis][:host],
                                           AppConfig[:redis][:port],
                                           AppConfig[:redis][:password])
    redis_client.connect
    StagingTaskLog.redis = redis_client
  end
end
