# Copyright (c) 2009-2011 VMware, Inc.
require File.join(File.dirname(__FILE__), '..', 'spec_helper')

require File.join(File.dirname(__FILE__), 'db_helper')

require 'socket'
require 'vcap/common'
require 'vcap/spec/forked_component/nats_server'

VCAP::Logging.setup_from_config( :level => :debug )

class HealthManagerComponent < VCAP::Spec::ForkedComponent::Base
  def initialize(cmd, pid_filename, config, output_basedir)
    super(cmd,'healthmanager', output_basedir, pid_filename )
    @config = config
  end
end
