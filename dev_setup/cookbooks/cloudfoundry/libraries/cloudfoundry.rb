require 'socket'
require 'ipaddr'

module CloudFoundry
  def cf_bundle_install(path)
    bash "Bundle install for #{path}" do
      cwd path
      user node[:deployment][:user]
      code "#{File.join(node[:ruby][:path], "bin", "bundle")} install"
      only_if { ::File.exist?(File.join(path, 'Gemfile')) }
    end
  end

  A_ROOT_SERVER = '198.41.0.4'
  def cf_local_ip(route = A_ROOT_SERVER)
    route ||= A_ROOT_SERVER
    orig, Socket.do_not_reverse_lookup = Socket.do_not_reverse_lookup, true
    UDPSocket.open {|s| s.connect(route, 1); s.addr.last }
  ensure
    Socket.do_not_reverse_lookup = orig
  end

  def cf_local_subnet(ip=nil)
    ip ||= cf_local_ip
    ip = ip.strip
    ip_regex = /^([1-9]|[1-9][0-9]|1[0-9][0-9]|2[0-4][0-9]|25[0-5])(\.([0-9]|[1-9][0-9]|1[0-9][0-9]|2[0-4][0-9]|25[0-5])){3}$/
    nil if ip =~ ip_regex
    ip if ip == "127.0.0.1" || ip == "localhost"
    mask = `ifconfig | grep #{ip} | cut -d: -f4`
    if mask =~ ip_regex
      network = IPAddr.new(ip, Socket::AF_INET).to_s
      mask_no = IPAddr.new(mask).to_i.to_s(2).count("1")
      "#{network}/#{mask_no}"
    else
      nil
    end
  end

end

class Chef::Recipe
  include CloudFoundry
end
