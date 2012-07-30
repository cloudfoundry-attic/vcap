module CloudFoundryMongo

  def id_and_checksum_for_version(version)
    id = ''
    checksum = ''
    machine = node[:kernel][:machine]
    Chef::Log.info("Machine: #{machine}")

    ids_for_version = node[:mongodb][:id]["#{version}"]
    checksums_for_version = node[:mongodb][:checksum]["#{version}"]

    if checksums_for_version && ids_for_version
      if !checksums_for_version.has_key?(machine) || !ids_for_version.has_key?(machine)
        Chef::Log.error("Installation of mongodb on #{machine} for version #{version} is not supported")
        return
      else
        id = ids_for_version["#{machine}"]
        checksum = checksums_for_version["#{machine}"]
      end
    else
      Chef::Log.error("Unsupported version: #{version}")
    end

    [id, checksum]
  end
end

class Chef::Recipe
  include CloudFoundryMongo
end
