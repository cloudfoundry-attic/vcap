module CloudFoundryRabbitmq

  def id_and_checksum_for_rabbitmq_version(version)
    id = ''
    checksum = ''
    id_for_version = node[:rabbitmq][:id]["#{version}"]
    checksum_for_version = node[:rabbitmq][:checksum]["#{version}"]

    if id_for_version.nil? || checksum_for_version.nil?
      raise "Unsupported version: #{version}"
    end

    [id_for_version, checksum_for_version]
  end
end

class Chef::Recipe
  include CloudFoundryRabbitmq
end
