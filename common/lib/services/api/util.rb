# Copyright (c) 2009-2011 VMware, Inc.
module VCAP
  module Services
    module Api
    end
  end
end

class VCAP::Services::Api::Util
  class << self
    def parse_label(label)
      raise ArgumentError, "Invalid label" unless label.match(/-/)
      name, _, version = label.rpartition(/-/)
      [name, version]
    end
  end
end
