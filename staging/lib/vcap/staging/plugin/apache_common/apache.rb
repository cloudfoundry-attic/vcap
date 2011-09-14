require 'nokogiri'
require 'fileutils'

class Apache
  def self.resource_dir
    File.join(File.dirname(__FILE__), 'resources')
  end

  def self.prepare(dir)
    FileUtils.cp_r(resource_dir, dir)
    output = %x[cd #{dir}; unzip -q resources/apache.zip]
    raise "Could not unpack Apache: #{output}" unless $? == 0
    FileUtils.rm(File.join(dir, "resources", "apache.zip"))
    dir
  end

end
