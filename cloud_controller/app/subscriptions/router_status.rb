# The CloudController versions of these methods take any command-line arguments into account.
host = CloudController.bind_address
port = CloudController.instance_port
uri  = AppConfig[:external_uri]
register_msg = { :host => host, :port => port, :uris => [uri], :tags => {:component => "CloudController"} }
json = Yajl::Encoder.encode(register_msg)

EM.next_tick do
  # Tell all current routers where to find us.
  NATS.publish('router.register', json)
  # Listen for router starts/restarts
  NATS.subscribe('router.start') { NATS.publish('router.register', json) }

  at_exit do
    # TODO - Introduce a reliable way to register shutdown callbacks for
    # the Rails instance. By the time we get here, EM is already stopped.
    NATS.start(:uri => AppConfig[:mbus]) do
      EM.add_timer(10) { EM.stop; exit }
      NATS.publish('router.unregister', json) do
        EM.stop; exit
      end
    end
  end
end
