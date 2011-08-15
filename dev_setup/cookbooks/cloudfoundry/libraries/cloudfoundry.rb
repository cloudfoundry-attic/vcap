require 'socket'

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
end

class Chef::Recipe
  include CloudFoundry
end
