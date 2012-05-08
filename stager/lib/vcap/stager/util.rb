module VCAP
  module Stager
  end
end

module VCAP::Stager::Util
  def self.path(*parts)
    path = File.join("../../../../", *parts)
    File.expand_path(path, __FILE__)
  end
end
