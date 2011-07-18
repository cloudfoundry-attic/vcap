require 'fileutils'

class Virgo

  def self.resource_dir
    File.join(File.dirname(__FILE__), 'resources')
  end

  def self.prepare(dir)
    FileUtils.cp_r(resource_dir, dir)
    output = %x[cd #{dir}; unzip -q resources/virgo.zip]
    raise "Could not unpack Virgo: #{output}" unless $? == 0
    webapp_path = File.join(dir, "virgo", "pickup")
    server_xml = File.join(dir, "virgo", "config", "tomcat-server.xml")
    FileUtils.rm_f(server_xml)
    FileUtils.rm(File.join(dir, "resources", "tomcat.zip"))
    FileUtils.rm(File.join(dir, "resources", "virgo.zip"))
    FileUtils.mv(File.join(dir, "resources", "droplet_virgo.yaml"), File.join(dir, "droplet.yaml"))
    FileUtils.mkdir_p(webapp_path)
    webapp_path
  end

end
