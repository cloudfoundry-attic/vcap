
EM.next_tick do

  NATS.subscribe('dea.advertise') do |msg|
    begin
      payload = Yajl::Parser.parse(msg, :symbolize_keys => true)
      CloudController::UTILITY_FIBER_POOL.spawn do
        DEAPool.process_advertise_message(payload)
      end
    rescue => e
      CloudController.logger.error("Exception processing dea advertisement: '#{msg}'")
      CloudController.logger.error(e)
    end
  end
  NATS.publish('dea.locate')
end
