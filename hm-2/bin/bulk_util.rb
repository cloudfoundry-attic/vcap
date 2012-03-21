#!/usr/bin/env ruby
home = File.join(File.dirname(__FILE__),'..')
ENV['BUNDLE_GEMFILE'] = "#{home}/Gemfile"

require 'rubygems'
require 'bundler/setup'
require File.join(home, 'lib','hm-2')

trap('INT') { NATS.stop { EM.stop }}
trap('SIGTERM') { NATS.stop { EM.stop }}


EM::run {

  NATS.start :uri => ENV['NATS_URI'] || 'nats://nats:nats@192.168.24.128:4222' do
    config = {
      'bulk' => {'host'=> ENV['BULK_URL'] || 'api.vcap.me', 'batch_size' => '2'},
    }
    VCAP::Logging.setup_from_config({'level'=>ENV['LOG_LEVEL'] || 'debug'})

    prov = HM2::BulkBasedExpectedStateProvider.new(config)
    prov.each_droplet do |id, droplet|
      puts "Droplet #{id}:"
      puts droplet.inspect
    end
    EM.add_timer(5) { EM.stop { NATS.stop } }
  end
}
