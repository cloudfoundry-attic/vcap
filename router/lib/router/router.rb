# Copyright (c) 2009-2011 VMware, Inc.
class Router

  VERSION = 0.98

  class << self
    attr_reader   :log, :notfound_redirect, :session_key, :trace_key
    attr_accessor :server, :local_server, :timestamp, :shutting_down
    attr_accessor :client_connection_count, :app_connection_count, :outstanding_request_count
    attr_accessor :inet, :port

    alias :shutting_down? :shutting_down

    def version
      VERSION
    end

    def config(config)
      @droplets = {}
      @client_connection_count = @app_connection_count = @outstanding_request_count = 0
      @log = VCAP.create_logger('router', :log_file => config['log_file'], :log_rotation_interval => config['log_rotation_interval'])
      @log.level =  config['log_level']
      if config['404_redirect']
        @notfound_redirect = "HTTP/1.1 302 Not Found\r\nConnection: close\r\nLocation: #{config['404_redirect']}\r\n\r\n".freeze
        log.info "Registered 404 redirect at #{config['404_redirect']}"
      end

      @session_key = config['session_key'] || '14fbc303b76bacd1e0a3ab641c11d11400341c5d'
      @trace_key = config['trace_key'] || '22'
    end

    def setup_listeners
      NATS.subscribe('router.register') { |msg|
        msg_hash = Yajl::Parser.parse(msg, :symbolize_keys => true)
        return unless uris = msg_hash[:uris]
        uris.each { |uri| register_droplet(uri, msg_hash[:host], msg_hash[:port], msg_hash[:tags]) }
      }
      NATS.subscribe('router.unregister') { |msg|
        msg_hash = Yajl::Parser.parse(msg, :symbolize_keys => true)
        return unless uris = msg_hash[:uris]
        uris.each { |uri| unregister_droplet(uri, msg_hash[:host], msg_hash[:port]) }
      }
    end

    def setup_sweepers
      @rps_timestamp = Time.now
      @current_num_requests = 0
      EM.add_periodic_timer(RPS_SWEEPER) { calc_rps }
      EM.add_periodic_timer(CHECK_SWEEPER) {
        check_registered_urls
        log_connection_stats
      }
    end

    def calc_rps
      # Update our timestamp and calculate delta for reqs/sec
      now = Time.now
      delta = (now - @rps_timestamp).to_f
      @rps_timestamp = now

      # Now calculate Requests/sec
      new_num_requests = VCAP::Component.varz[:requests]
      VCAP::Component.varz[:requests_per_sec] = ((new_num_requests - @current_num_requests)/delta).to_i
      @current_num_requests = new_num_requests

      # Go ahead and calculate rates for all backends here.
      apps = []
      @droplets.each_pair do |url, instances|
        total_requests = 0
        clients_hash = Hash.new(0)
        instances.each do |droplet|
          total_requests += droplet[:requests]
          droplet[:requests] = 0
          droplet[:clients].each_pair { |ip,req| clients_hash[ip] += req }
          droplet[:clients] = Hash.new(0) # Wipe these per sweep
        end

        # Grab top 5 clients responsible for the traffic
        clients, clients_array = [], clients_hash.sort { |a,b| b[1]<=>a[1] } [0,4]
        clients_array.each { |c| clients << { :ip => c[0], :rps => (c[1]/delta).to_i } }

        # Add in clients if they exist and the entry if rps != 0
        if (rps = (total_requests/delta).to_i) > 0
          entry = { :url => url, :rps => rps }
          entry[:clients] = clients unless clients.empty?
          apps << entry unless entry[:rps] == 0
        end
      end

      top_10 = apps.sort { |a,b| b[:rps]<=>a[:rps] } [0,9]
      VCAP::Component.varz[:top_app_requests] = top_10
      #log.debug "Calculated all request rates in  #{Time.now - now} secs."
    end

    def check_registered_urls
      start = Time.now

      # If NATS is reconnecting, let's be optimistic and assume
      # the apps are there instead of actively pruning.
      if NATS.client.reconnecting?
        log.info "Suppressing checks on registered URLS while reconnecting to mbus."
        @droplets.each_pair do |url, instances|
          instances.each { |droplet| droplet[:timestamp] = start }
        end
        return
      end

      to_drop = []
      @droplets.each_pair do |url, instances|
        instances.each do |droplet|
          to_drop << droplet if ((start - droplet[:timestamp]) > MAX_AGE_STALE)
        end
      end
      log.debug "Checked all registered URLS in #{Time.now - start} secs."
      to_drop.each { |droplet| unregister_droplet(droplet[:url], droplet[:host], droplet[:port]) }
    end

    def connection_stats
      tc = EM.connection_count
      ac = Router.app_connection_count
      cc = Router.client_connection_count
      "Connections: [Clients: #{cc}, Apps: #{ac}, Total: #{tc}]"
    end

    def log_connection_stats
      tc = EM.connection_count
      ac = Router.app_connection_count
      cc = Router.client_connection_count
      log.info connection_stats
    end

    def generate_session_cookie(droplet)
      token = [ droplet[:url], droplet[:host], droplet[:port] ]
      c = OpenSSL::Cipher::Cipher.new('blowfish')
      c.encrypt
      c.key = @session_key
      e = c.update(Marshal.dump(token))
      e << c.final
      [e].pack('m0').gsub("\n",'')
    end

    def decrypt_session_cookie(key)
      e = key.unpack('m*')[0]
      d = OpenSSL::Cipher::Cipher.new('blowfish')
      d.decrypt
      d.key = @session_key
      p = d.update(e)
      p << d.final
      Marshal.load(p)
    rescue
      nil
    end

    def lookup_droplet(url)
      @droplets[url]
    end

    def register_droplet(url, host, port, tags)
      return unless host && port
      url.downcase!
      droplets = @droplets[url] || []
      # Skip the ones we already know about..
      droplets.each { |droplet|
        # If we already now about them just update the timestamp..
        if(droplet[:host] == host && droplet[:port] == port)
          droplet[:timestamp] = Time.now
          return
        end
      }
      tags.delete_if { |key, value| key.nil? || value.nil? } if tags
      droplet = {
        :host => host,
        :port => port,
        :connections => [],
        :clients => Hash.new(0),
        :url => url,
        :timestamp => Time.now,
        :requests => 0,
        :tags => tags
      }
      add_tag_metrics(tags) if tags
      droplets << droplet
      @droplets[url] = droplets
      VCAP::Component.varz[:urls] = @droplets.size
      VCAP::Component.varz[:droplets] += 1
      log.info "Registering #{url} at #{host}:#{port}"
      log.info "#{droplets.size} servers available for #{url}"
    end

    def unregister_droplet(url, host, port)
      log.info "Unregistering #{url} for host #{host}:#{port}"
      url.downcase!
      droplets = @droplets[url] || []
      dsize = droplets.size
      droplets.delete_if { |d| d[:host] == host && d[:port] == port}
      @droplets.delete(url) if droplets.empty?
      VCAP::Component.varz[:urls] = @droplets.size
      VCAP::Component.varz[:droplets] -= 1 unless (dsize == droplets.size)
      log.info "#{droplets.size} servers available for #{url}"
    end

    def add_tag_metrics(tags)
      tags.each do |key, value|
        key_metrics = VCAP::Component.varz[:tags][key] ||= {}
        key_metrics[value] ||= {
          :requests => 0,
          :latency => VCAP::RollingMetric.new(60),
          :responses_2xx => 0,
          :responses_3xx => 0,
          :responses_4xx => 0,
          :responses_5xx => 0,
          :responses_xxx => 0
        }
      end
    end

  end
end
