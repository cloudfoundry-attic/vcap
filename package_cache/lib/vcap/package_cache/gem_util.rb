module GemUtil
  class << self
    def gem_drop_suffix(gem_name)
      gem_name.chomp(File.extname(gem_name))
    end

    def gem_version(gem_name)
      gem_drop_suffix(gem_name).split('-').last
    end

    def gem_base_name(gem_name)
      gem_drop_suffix(gem_name).split('-')[0..-2].join('-')
    end

    def gem_to_package(gem_name)
      gem_drop_suffix(gem_name) + '.tgz'
    end

    def gem_to_url(gem_name)
      "http://production.s3.rubygems.org/gems/#{gem_name}"
    end
  end
end
