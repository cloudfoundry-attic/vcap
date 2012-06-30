module CloudFoundryMongo

  def checksum_for_version(version)
    checksum = ''
    machine = node[:kernel][:machine]
    Chef::Log.info("Machine: #{machine}")

    checksums_for_version = node[:mongodb][:checksum]["#{version}"]

    if checksums_for_version
      if !checksums_for_version.has_key?(machine)
        Chef::Log.error("Installation of mongodb on #{machine} for version #{version} is not supported")
        return
      else
        checksum = checksums_for_version["#{machine}"]
      end
    else
      Chef::Log.error("Unsupported version: #{version}")
    end

    checksum
  end
end

class Chef::Recipe
  include CloudFoundryMongo
end
