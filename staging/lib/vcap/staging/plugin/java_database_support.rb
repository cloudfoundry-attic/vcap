module JavaDatabaseSupport
  SERVICE_DRIVER_HASH = {
    "mysql-5.1" => '*mysql-connector-java-*.jar',
    "postgresql-9.0" => '*postgresql-*.jdbc*.jar'
  }

  def copy_service_drivers(driver_dest,services)
    return if services == nil
    drivers = services.select { |svc|
      SERVICE_DRIVER_HASH.has_key?(svc[:label])
    }
    drivers.each { |driver|
      copy_jar SERVICE_DRIVER_HASH[driver[:label]], driver_dest
    } if drivers
  end

  private
  def copy_jar jar, dest
    resource_dir = File.join(File.dirname(__FILE__), 'resources')
    Dir.chdir(resource_dir) do
      jar_path = File.expand_path(Dir.glob(jar).first)
      FileUtils.mkdir_p dest
        Dir.chdir(dest) do
	  FileUtils.cp(jar_path, dest) if Dir.glob(jar).empty?
	end
    end
  end
end
