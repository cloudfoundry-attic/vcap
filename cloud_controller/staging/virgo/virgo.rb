require 'fileutils'
require 'yaml'

class Virgo

  def self.resource_dir
    File.join(File.dirname(__FILE__), 'resources')
  end

  def self.repository
    "repository"
  end

  def self.prepare(dir)
    FileUtils.cp_r(resource_dir, dir)
    output = %x[cd #{dir}; unzip -q resources/virgo.zip]
    raise "Could not unpack Virgo: #{output}" unless $? == 0
    webapp_path = File.join(dir, "virgo", "artifacts")
    server_xml = File.join(dir, "virgo", "config", "tomcat-server.xml")
    FileUtils.rm_f(server_xml)
    FileUtils.rm(File.join(dir, "resources", "virgo.zip"))
    FileUtils.mv(File.join(dir, "resources", "droplet.yaml"), File.join(dir, "droplet.yaml"))
    FileUtils.mkdir_p(webapp_path)
    webapp_path
  end

  def self.detect_file_extension(webapppath)
    Dir.chdir(webapppath) do
      if !Dir.glob("*.plan").empty?
        return "plan"
      end
    end

    manifest_mf = File.join(webapppath, "META-INF/MANIFEST.MF")
    if File.file? manifest_mf
      manifest = YAML.load_file(manifest_mf)
      return "jar" if manifest["Bundle-SymbolicName"]
      return "par" if manifest["Application-SymbolicName"]
    end

    "war"
  end

end
