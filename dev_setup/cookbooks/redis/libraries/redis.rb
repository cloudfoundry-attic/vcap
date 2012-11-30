module CloudFoundryRedis

  def id_and_checksum_for_redis_version(version)
    id = ''
    checksum = ''
    id_for_version = node[:redis][:id]["#{version}"]
    checksum_for_version = node[:redis][:checksum]["#{version}"]

    if id_for_version.nil? || checksum_for_version.nil?
      raise "Unsupported version: #{version}"
    end

    [id_for_version, checksum_for_version]
  end
end

class Chef::Recipe
  include CloudFoundryRedis
end
