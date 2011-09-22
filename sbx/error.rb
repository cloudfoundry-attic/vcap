class LXC_Error < StandardError; end
class LXC_BootstrapError < LXC_Error; end
class LXC_CreateError < LXC_Error; end
class LXC_StartError < LXC_Error; end
class LXC_StopError < LXC_Error; end
class LXC_DestroyError < LXC_Error; end

class LXC_IPTablesError < LXC_Error

  attr_reader :msg, :chain, :ip, :extern, :local

  def initialize(msg, chain, ip, extern_port, local_port)
    @msg = msg
    @chain = chain
    @ip, @extern, @local = ip, extern_port, local_port
    super("Error in iptables #{@action} #{@chain}: #{@msg}")
  end

end
