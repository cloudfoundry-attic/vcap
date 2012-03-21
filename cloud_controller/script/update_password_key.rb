# Copyright (c) 2012 Rakuten, Inc.
#
# A utility script for updating password key 
#
# If you change password key in cloud_controller.yml, you need to update database records
# to update the environment column in apps table, which is encrypted.
#
# Usage
#
#   $ cd CLOUD_CONTROLLER_ROOT
#   $ CLOUD_CONTROLLER_CONFIG=path/to/cloud_controller.yml path/to/ruby script/rails runner \
#       script/update_password_key.rb -o 'oldkey' -n 'newkey'
#

require 'optparse'

old_key = nil
new_key = nil

opt = OptionParser.new
opt.on('-o oldkey') { |v| old_key = v }
opt.on('-n newkey') { |v| new_key = v }
opt.parse!(ARGV)

if old_key.blank?
  $stderr.puts "Error: oldkey must be specified."
  $stderr.puts opt.help
  exit 1
end

if new_key.blank?
  $stderr.puts "Error: newkey must be specified."
  $stderr.puts opt.help
  exit 1
end

App.find(:all).each do |app|
  json_crypt = app.environment_json
  environment = if json_crypt.blank?
                  []
                else
                  e = json_crypt.unpack('m*')[0]
                  d = OpenSSL::Cipher::Cipher.new('blowfish')
                  d.key = old_key
                  json = d.update(e)
                  json << d.final
                  Yajl::Parser.parse(json)
                end
 
  json = Yajl::Encoder.encode(environment)
  c = OpenSSL::Cipher::Cipher.new('blowfish')
  c.encrypt
  c.key = new_key
  json_crypt = c.update(json)
  json_crypt << c.final 
  app.environment_json = [json_crypt].pack('m0').gsub("\n", '')
  app.save!
  puts "Key Updte DONE: #{app.name} (#{app.id})"
end

