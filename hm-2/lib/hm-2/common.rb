module HM2 module Constants end end

module HM2::Common

  def get_interval_from_config_or_constant(name, config)
    intervals = config[:intervals] || config['intervals'] || {}
    get_param_from_config_or_constant(name,intervals)
  end

  def get_param_from_config_or_constant(name, config)
    value = config[name] || config[name.to_sym] || config[name.to_s]
    unless value
      const_name = name.to_s.upcase
      if HM2.const_defined?( const_name )
        value = HM2.const_get( const_name )
      end
    end
    raise ArgumentError, "undefined parameter #{name}" unless value
    value
  end

  def varz
    find_hm_component(:varz)
  end
  def scheduler
    find_hm_component(:scheduler)
  end
  def nudger
    find_hm_component(:nudger)
  end
  def known_state_provider
    find_hm_component(:known_state_provider)
  end
  def expected_state_provider
    find_hm_component(:expected_state_provider)
  end
  def register_hm_component(name, component)
    hm_registry[name] = component
  end

  def find_hm_component(name)
    unless component = hm_registry[name]
      raise ArgumentError, "component #{name} can't be found in the registry #{@config}"
    end
    component
  end
  def hm_registry
    @config[:health_manager_component_registry] ||= {}
  end

  def get_logger(name='hm-2')
    VCAP::Logging.logger(name)
  end

  def encode_json(obj={})
    Yajl::Encoder.encode(obj)
  end
  def parse_json(string='{}')
    Yajl::Parser.parse(string)
  end

  def now
    HM2::Manager.now
  end
  def parse_utc(time)
    Time.parse(time).to_i
  end
end
