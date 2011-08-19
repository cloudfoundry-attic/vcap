load 'user_pool.rb'
require 'pp'
up = UserPool.new
up.install_pool($test_pool)
puts "printing free user list"
pp up.free_users

puts "printing busy list users"
pp up.busy_users

user1 = up.alloc_user
user2 = up.alloc_user
up.free_user(user1)
up.free_user(user2)

up.remove_pool
