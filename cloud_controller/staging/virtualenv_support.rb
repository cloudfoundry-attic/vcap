module VirtualenvSupport

  def setup_virtualenv(requirements=nil)
    cmds = []
    cmds << "virtualenv --distribute env"
    requirements.each { |package|
      cmds << "env/bin/pip install #{package}"
    }
    cmds.join("\n")
  end

end
