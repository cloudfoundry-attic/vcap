module VCAP
  class UserPool
    module Defs
      TEST_POOL = {
          :uid_base => 31000,
          :pool_size => 5,
          :user_prefix => 'test',
          :group_name => 'test'
      }
      PACKAGE_CACHE_POOL = {
          :uid_base => 32000,
          :pool_size => 128,
          :user_prefix => 'package_cache',
          :group_name => 'package_cache'
      }
    end
  end
end


