module GemUtil
  class << self
    def gem_drop_suffix(gem_name)
      base_gem,_,_ = gem_name.rpartition('.')
      base_gem
    end

    def gem_to_package(gem_name)
      gem_drop_suffix(gem_name) + '.tgz'
    end

    def gem_to_url(gem_name)
      "http://production.s3.rubygems.org/gems/#{gem_name}"
    end
  end
end
