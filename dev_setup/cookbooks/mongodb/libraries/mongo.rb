module CloudFoundryMongo

  def id_and_checksum_for_version(version)
    id = node[:mongodb][:id]["#{version}"]
    checksum = node[:mongodb][:checksum]["#{version}"]

    [id, checksum]
  end
end

class Chef::Recipe
  include CloudFoundryMongo
end
