module JavaAutoconfig

  AUTOSTAGING_JAR = 'auto-reconfiguration-0.6.3.BUILD-SNAPSHOT.jar'

  def copy_autostaging_jar(dest)
    FileUtils.mkdir_p dest
    jar_path = File.join(File.dirname(__FILE__), 'resources', AUTOSTAGING_JAR)
    FileUtils.cp(jar_path, dest)
  end
end
