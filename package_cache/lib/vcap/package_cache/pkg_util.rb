
module PkgUtil
  class << self
    def drop_extension(name)
      name.chomp(File.extname(name))
    end

    def to_package(name)
      drop_extension(name) + '.tgz'
    end
  end
end
