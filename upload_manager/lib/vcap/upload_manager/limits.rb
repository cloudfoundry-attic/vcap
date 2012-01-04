module VCAP module UploadManager end end

module VCAP::UploadManager::Limits
    RESOURCE_LIST_MAX = 1024  #max number of entries in a resource list.
    UNPACKED_APP_MAX = 256 * 1024 * 1024 #256 meg max unpacked app size.
    PACKED_APP_MAX = 256 * 1024 * 1024   #256 meg max packed app size.
end
