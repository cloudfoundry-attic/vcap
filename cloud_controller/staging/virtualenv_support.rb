module VirtualenvSupport

  def setup_virtualenv
    cmds = []
    cmds << "virtualenv --no-site-packages env"
    cmds << "env/bin/pip install gunicorn"
    cmds.join("\n")
  end

end
