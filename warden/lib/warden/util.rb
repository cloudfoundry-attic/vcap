module Warden
  module Util
    def self.path(*args)
      File.expand_path(File.join("..", "..", "..", *args), __FILE__)
    end
  end
end
