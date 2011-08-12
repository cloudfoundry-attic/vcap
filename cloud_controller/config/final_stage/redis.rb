if AppConfig[:redis]
  EM::Hiredis.logger = CloudController.logger

  # This will be run once the event loop has started
  EM.next_tick do
    redis_client = EM::Hiredis::Client.new(AppConfig[:redis][:host],
                                           AppConfig[:redis][:port],
                                           AppConfig[:redis][:password])
    redis_client.connect
    Resque.redis = redis_client
    Resque.redis.namespace = AppConfig[:redis][:namespace] if AppConfig[:redis][:namespace]
    VCAP::Stager::TaskResult.redis = redis_client
  end
end
