
module PkgUtil
  class << self
    def drop_extension(name)
      name.chomp(File.extname(name))
    end

    def to_package(name, runtime)
      drop_extension(name) + "@#{runtime}"  + '.tgz'
    end
  end
end
