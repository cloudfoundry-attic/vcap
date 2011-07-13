module CloudController
  class << self
    def deas
      @deas ||= {}
    end

    def register_dea(hello)
      deas[hello[:id]] = hello
    end

    def unregister_dea(id)
      deas.delete(id)
    end

    def known_runtimes
      deas.values.inject({}) do |a, d|
        CloudController.logger.debug "XXXXXXXXXXXXXXXXXXXXXXXXXX #{a.inspect} YYYYYYYYYYYYYY #{d.inspect} ZZZZZZZZZZZZZZZZ #{deas.inspect}"
        a.merge(d[:runtimes])
      end
    end
  end
end

EM.next_tick do
  # Keep track of running DEAs so we know what runtimes we support.

  NATS.publish('cc.start')

  NATS.subscribe('dea.cc.hello') do |msg|
    begin
      payload = Yajl::Parser.parse(msg, :symbolize_keys => true)
      CloudController.logger.debug("DEA says hello: #{msg}")
      CloudController.register_dea(payload)
    rescue => e
      CloudController.logger.error("Exception processing DEA hello: '#{msg}'")
      CloudController.logger.error(e)
    end
  end

  NATS.subscribe('dea.cc.goodbye') do |msg|
    begin
      payload = Yajl::Parser.parse(msg, :symbolize_keys => true)
      CloudController.logger.debug("DEA says goodbye: #{msg}")
      CloudController.unregister_dea(payload[:id])
    rescue => e
      CloudController.logger.error("Exception processing DEA goodbye: '#{msg}'")
      CloudController.logger.error(e)
    end
  end
end
