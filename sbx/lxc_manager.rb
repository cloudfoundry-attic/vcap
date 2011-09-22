require 'rubygems'
require 'yajl'
require 'fileutils'
require 'eventmachine'
require 'fileutils'
require 'fiber'
require File.expand_path('../fiber_mutex.rb', __FILE__)
require File.expand_path('../error.rb', __FILE__)

class LXC_Manager

    LXC_HOME = "/lxc"

    attr_reader :ip_pool, :port_pool, :containers, :running

    def initialize
      @ipt_mutex = FiberMutex.new

      @ip_pool = []
      @port_pool = []
      @containers = []
      @running = []

      2.upto 254 do |i|
        @ip_pool << "192.168.0.#{i}"
      end
      32768.upto 61000 do |port|
        @port_pool << port
      end
    end

    def create(config=nil, &blk)
      fiber = Fiber.new do
        begin
          config = "" if !config
          auth = get_auth_token
          ip = assign_ip
          port = assign_port
          handle = auth.dup << "_" << ip << "_"<< port
          path = "#{LXC_HOME}/#{handle}"

          bootstrap_fs path
          write_network_config handle
          write_config config, handle
          write_fstab(handle)
          lxc_create(handle, path)
          lxc_start(handle)
          map_ports handle, config

        rescue LXC_BootstrapError => e
          remove_bootstrap(path)
          handle = e.message
        rescue LXC_CreateError => e
          remove_bootstrap(path)
          handle = e.message
        rescue LXC_StartError => e
          syscall("lxc-destroy -n #{handle}")
          remove_bootstrap(path)
          handle = e.meesage
        rescue LXC_IPTablesError => e
          remove_ip_rules(e)
          syscall("lxc-stop -n #{handle}")
          syscall("lxc-destroy -n #{handle}")
          remove_bootstrap(path)
          handle = e.message
        ensure
          blk.call(handle) if blk
        end
      end
      fiber.resume
   end


    def destroy(handle, &blk)
      fiber = Fiber.new do
        begin
          path = "#{LXC_HOME}/#{handle}"

          lxc_stop(handle)
          lxc_destroy(handle)

          ip = ip_from_handle handle
          @ip_pool << ip

          if File.exists? "#{path}/ports"
            File.open("#{path}/ports", "r").each do |line|
              extern_port = line.split("\t")[1]
              @port_pool << extern_port
            end
            unmap_ports handle
            File.delete "#{path}/ports"
          end

          FileUtils.remove_entry_secure path
          resp = "Deleted #{handle}"

        rescue LXC_StopError => e
          if lxc_exists?(handle) && lxc_running?(handle)
            retry
          else
            resp = "Error: Cannot delete #{handle}. The container #{handle} doesn not exist."
          end
        rescue LXC_DestroyError => e
          retry if lxc_exists?(handle)
          resp = "Error: Cannot delete #{handle}. The container #{handle} does not exist."
        rescue LXC_IPTablesError => e
          remove_ip_rules(e)
          resp = "Deleted #{handle}"
        rescue => e
          resp = e.message
        ensure
          blk.call(resp) if blk
        end
      end
      fiber.resume
    end

    private

    DEFAULT_CONFIG = {
      "lxc.tty" => "4",
      "lxc.pts" => "1024",
      "lxc.cgroup.devices.deny" => "a",
      "lxc.cgroup.devices.allow" => [
        "c 1:3 rwm",
        "c 1:5 rwm",
        "c 5:1 rwm",
        "c 5:0 rwm",
        "c 4:0 rwm",
        "c 4:1 rwm",
        "c 1:9 rwm",
        "c 1:8 rwm",
        "c 136:* rwm",
        "c 5:2 rwm",
        "c 254:0 rwm"
      ],
      "lxc.network.type" => "veth",
      "lxc.network.flags" => "up",
      "lxc.network.link" => "br0",
      "lxc.network.name" => "eth0",
      "lxc.network.mtu" => "1500"
    }

    def syscall(cmd)
      f = Fiber.current
      EM.system(cmd) { |output, status|
        err = output if status.exitstatus != 0
        f.resume(err)
      }
      Fiber.yield
    end

    def remove_ip_rules(e)
      rules = `iptables -t nat -L PREROUTING`.split("\n").select { |x| x =~ /#{e.ip}/ }
      rules.each do |rule|
        rule =~ /tcp dpt:/
        extern = $~.post_match.to_i
        rule =~ /#{e.ip}:/
        local = $~.post_match.to_i
        `iptables -D PREROUTING -t nat -i eth0 -p tcp --dport #{extern} -j DNAT --to #{e.ip}:#{local}`
        input_rules = `iptables -L INPUT`.split("\n").select { |x| x =~ /#{extern}/ }
        input_rules.each do
          `iptables -D INPUT -p tcp -m state --state NEW --dport #{extern} -i eth0 -j ACCEPT`
        end
      end
    end

    def bootstrap_fs(path)
      begin
        Dir.mkdir path
      rescue
        raise LXC_BootstrapError
      end
      err = syscall("#{LXC_HOME}/lxc-debian -p #{path} create")
      raise LXC_BootstrapError if err
    end

    def remove_bootstrap(path)
      if Dir.exists? path
        FileUtils.remove_entry_secure path
      end
    end

    def lxc_create(handle, path)
      err = syscall("lxc-create -n #{handle} -f #{path}/config")
      raise LXC_CreateError if err
      @containers << handle
    end

    def lxc_start(handle)
      `lxc-start -n #{handle} -d`; result = $?
      raise LXC_StartError unless result.success?
      @running << handle
    end

    def lxc_destroy(handle)
      err = syscall("lxc-destroy -n #{handle}")
      raise LXC_DestroyError if err
      @containers.delete(handle)
    end

    def lxc_stop(handle)
      err = syscall("lxc-stop -n #{handle}")
      raise LXC_StopError if err
      @running.delete(handle)
    end

    def ip_from_handle(handle)
      handle.split("_")[1]
    end

    def map_ports(handle, config)
      config = Yajl::Parser.parse config
      return if !config

      path = "#{LXC_HOME}/#{handle}"

      requested_ports = config["ports"]
      ip = ip_from_handle handle

      fd = File.open "#{path}/ports", "w"
      requested_ports.each do |port|
        extern_port = @port_pool.pop
        fd.puts "#{port}\t#{extern_port}"

        @ipt_mutex.lock
        err = syscall("iptables -A PREROUTING -t nat -i eth0 -p tcp --dport #{extern_port} -j DNAT --to #{ip}:#{port}")
        if err
          @ipt_mutex.unlock
          raise LXC_IPTablesError.new(err, "PREROUTING", ip, extern_port, port)
        end

        err = syscall("iptables -A INPUT -p tcp -m state --state NEW --dport #{extern_port} -i eth0 -j ACCEPT")
        err = -1
        if err
          @ipt_mutex.unlock
          raise LXC_IPTablesError.new(err, "INPUT", ip, extern_port, port)
        end
        @ipt_mutex.unlock
      end
      fd.close
    end

    def unmap_ports(handle)
      ip = ip_from_handle handle
      path = "#{LXC_HOME}/#{handle}"
      File.open("#{path}/ports", "r").each do |line|
        local_port = line.split("\t")[0]
        extern_port = line.split("\t")[1]
        @ipt_mutex.lock
        err = syscall("iptables -D PREROUTING -t nat -i eth0 -p tcp --dport #{extern_port} -j DNAT --to #{ip}:#{local_port}")
        if err
          @ipt_mutex.unlock
          raise LXC_IPTablesError.new(err, "PREROUTING", ip, extern_port, local_port)
        end
        err = syscall("iptables -D INPUT -p tcp -m state --state NEW --dport #{extern_port} -i eth0 -j ACCEPT")
        if err
          @ipt_mutex.unlock
          raise LXC_IPTablesError.new(err, "INPUT", ip, extern_port, local_port)
        end
        @ipt_mutex.unlock
      end
    end

    def lxc_exists?(handle)
      @containers.index(handle) != nil
    end

    def lxc_running?(handle)
      @running.index(handle) != nil
    end

    def write_network_config(handle)
      fd = File.open("#{LXC_HOME}/#{handle}/rootfs/etc/network/interfaces", "w")
      fd.puts "auto lo
iface lo inet loopback

auto eth0
iface eth0 inet static
address #{ip_from_handle handle}
netmask 255.255.255.0
broadcast 192.168.0.255
gateway 192.168.0.1"
      fd.close
    end

    def get_auth_token
      rand(36**8).to_s(36)
      #TODO - use VCAP.secure_uuid
    end

    def assign_ip
      ip = @ip_pool.pop
      ip || (raise "No IPs to allocate for containers")
    end

    def assign_port
      "22"
    end

    def write_fstab(container_name)
      path = "#{LXC_HOME}/#{container_name}"
      fd = File.open "#{path}/fstab", "w"
      fd.puts "none #{path}/rootfs/proc proc defaults 0 0
none #{path}/rootfs/dev/pts devpts defaults 0 0
none #{path}/rootfs/sys sysfs defaults 0 0"
      fd.close
    end

    def write_config(config, container_name)
      path = "#{LXC_HOME}/#{container_name}"
      fd = File.open("#{path}/config", "w")

      fd.puts "lxc.rootfs = #{path}/rootfs"
      fd.puts "lxc.mount = #{path}/fstab"

      lxc_config = update_config(config)
      lxc_config = lxc_config.sort { |a, b| sort_callback(a, b) }

      lxc_config.each do |key, value|
        if value.class == Array
          value.each do |sub|
            fd.puts "#{key} = #{sub}"
          end
        else
          fd.puts "#{key} = #{value}"
        end
      end
      fd.close
    end

    def update_config(config)

      return DEFAULT_CONFIG.dup unless config

      lxc_config = DEFAULT_CONFIG.dup
      network_config = {}

      user_config = Yajl::Parser.parse(config)
      return lxc_config if !user_config
      user_config.each do |key, value|
        if key =~ /^lxc\./
          lxc_config[key] = value
        end
      end
      lxc_config
    end

    def sort_callback(a, b)
      top_group_order = ["tty", "pts", "rootfs", "mount", "cgroup", "network"].freeze
      network_order = ["type", "flags", "link", "name", "mtu"].freeze

      a_split = a[0].split('.')
      b_split = b[0].split('.')

      # Sort by top group
      a_group = top_group_order.find_index(a_split[1])
      b_group = top_group_order.find_index(b_split[1])
      return a_group <=> b_group unless a_group == b_group

      if a_split[1] == "cgroup"
        return b[0] <=> a[0] # We want devices.deny before devices.allow

      elsif a_split[1] == "network"
      # Sort within the network group
        a_net = network_order.find_index(a_split[2])
        b_net = network_order.find_index(b_split[2])
        return a_net <=> b_net

      else
        # Otherwise, sort alphabetically
        return a[0] <=> b[0]
      end
    end

end
