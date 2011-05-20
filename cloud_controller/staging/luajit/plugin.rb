class LuajitPlugin < StagingPlugin
  def framework
    'luajit'
  end

  def stage_application
    Dir.chdir(destination_directory) do
      create_app_directories
      copy_source_files
      create_startup_script
    end
  end

  def start_command
    "/usr/local/bin/wsapi -p $VCAP_APP_PORT"
  end

  private
  def startup_script
    vars = environment_hash
    vars['CGILUA_CONF'] = "$PWD/luaconf"
    generate_startup_script(vars) do
      create_cgilua_conf
    end
  end
  
  def create_cgilua_conf
    cnf = []
    cnf << "mkdir luaconf"
    cnf << %Q{echo "cgilua.addopenfunction (cgilua.htmlheader)" >> luaconf/config.lua}
    cnf << %Q{echo "cgilua.addscripthandler ('.lua', cgilua.doscript)" >> luaconf/config.lua}
    cnf << %Q{echo "cgilua.addscripthandler ('.lp', cgilua.handlelp)" >> luaconf/config.lua}
    cnf.join("\n")
  end

end