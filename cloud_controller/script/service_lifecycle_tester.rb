require File.expand_path('../../config/boot',  __FILE__)
require 'config/environment'
require 'net/http'
require 'pp'
require 'services/api'

def do_request(klass, host, port, path, token, req=VCAP::Services::Api::EMPTY_REQUEST)
  hdr = {
    'Content-Type'  => 'application/json',
    'Authorization' => token,
  }
  post = klass.new(path, initheader = hdr)
  post.body = req.encode
  resp = Net::HTTP.new(host, port).start {|http| http.request(post)}
  resp
end

def assert_resp_ok(resp)
  unless resp.is_a? Net::HTTPOK
    puts "Got non ok response: #{resp.inspect}"
    info = JSON.parse(resp.body)
    puts info.pretty_inspect
    exit 1
  end
end

# Simple test script that walks through the following:
# 1. Provision service
# 2. Bind service
# 3. Unbind service
# 4. Unprovision

svcs = {
  'redis' => '2',
  'mysql' => '5.1',
  'postgresql' => '9.0',
}
svc = nil
svc = ARGV[0] if ARGV.length > 0

unless svcs[svc]
  puts "Usage: service_lifecycle_tester.rb [redis || mysql || postgresql]"
  exit 1
end

host = 'localhost'
port = 3000
acct = UserToken.create('foo@bar.com').encode()

#################### Provision ####################
puts "Provisioning..."

req = VCAP::Services::Api::ProvisionRequest.new(
  :label => "#{svc}-#{svcs[svc]}",
  :name  => 'foobar',
  :plan  => 'free'
)
resp = do_request(Net::HTTP::Post, host, port, '/services/v1/configurations', acct, req)
assert_resp_ok(resp)

puts "Provisioned successfully, resp:"
conf = JSON.parse(resp.body)
puts conf.pretty_inspect
puts

#################### Bind ####################
puts "Binding..."

req = VCAP::Services::Api::CloudControllerBindRequest.new(
  :app_name        => 'foobar',
  :service_id      => conf['service_id'],
  :binding_options => {}
)
resp = do_request(Net::HTTP::Post, host, port, '/services/v1/bindings', acct, req)
assert_resp_ok(resp)

puts "Successfully bound service, resp:"
info = JSON.parse(resp.body)
puts info.pretty_inspect
puts

#################### Unbind ####################
puts "Unbinding..."

resp = do_request(Net::HTTP::Delete, host, port, "/services/v1/bindings/#{info['binding_token']}", acct)
assert_resp_ok(resp)

puts "Successfully unbound service, resp:"
info = JSON.parse(resp.body)
puts info.pretty_inspect
puts

#################### Unprovisioning ####################
puts "Unprovisioning"

resp = do_request(Net::HTTP::Delete, host, port, "/services/v1/configurations/#{conf['service_id']}", acct)
assert_resp_ok(resp)

puts "Successfully unprovisioned service, resp:"
info = JSON.parse(resp.body)
puts info.pretty_inspect
puts


