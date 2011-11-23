class NetPlugin < StagingPlugin
  def framework
    'net'
  end

  def stage_application
    Dir.chdir(destination_directory) do
      create_app_directories
      copy_source_files
      create_startup_script
    end
  end

  def generate_startup_script(env_vars = {})
    after_env_before_script = block_given? ? yield : "\n"
    #todo: vladi: VMC_APP_NAME is deprecated, this should be replaced with the proper VCAP env variable
    template = <<-SCRIPT
    <%= after_env_before_script %>
    $appName = $env:VMC_APP_NAME
    $appPort = $env:VCAP_APP_PORT
    $appName = $appName.Replace("'", "")
    $appPort = $appPort.Replace("'", "")
    $rLayer = $args[0]
    cd app
    $appDir = [System.IO.Directory]::GetCurrentDirectory();
    $physicalPath = "$($appDir)\\app\\"
    $psi = new-object System.Diagnostics.ProcessStartInfo
    $psi.Arguments = "-add -name=$appName$appPort -port=$appPort -autowire -watcher -path=`"$physicalPath`""
    $psi.FileName = $rLayer
    $psi.CreateNoWindow = true
    $psi.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Hidden
    $process = [System.Diagnostics.Process]::Start($psi)
    echo $process.Id >> ..\\run.pid
    <%= stop_script_template.lines.map { |l| "echo " + l.strip + " >> ..\\\\stop\r\n" }.join %>
    Wait-Process -Id $process.Id
    SCRIPT
	
    ERB.new(template).result(binding).lines.reject {|l| l =~ /^\s*$/}.join
  end

  def stop_script_template
    <<-SCRIPT
    "&`"$($rLayer)`" -stop -pid=$($process.Id)"
    SCRIPT
  end  
  
  private
  def startup_script
    vars = environment_hash
    generate_startup_script(vars)  
  end

end

