EM.next_tick do
  NATS.subscribe('cloudcontroller.bulk.credentials') do |_, reply|
    NATS.publish(reply, AppConfig[:bulk_api][:auth].to_json)
  end
end
