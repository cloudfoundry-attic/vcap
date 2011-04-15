class PhpPlugin < StagingPlugin
  # TODO - Is there a way to avoid this without some kind of 'register' callback?
  # e.g. StagingPlugin.register('sinatra', __FILE__)
  def framework
    'php'
  end

  def stage_application
    # TODO: Stop script uses kill -9, and this means we're not cleaning up php-cgi workers.
    Dir.chdir(destination_directory) do
      create_app_directories
      copy_source_files
      create_startup_script
      create_lighttpd_config
    end
  end

  def start_command
    # We can't pass through $@, since the -p makes lighttpd dump out its config
    "lighttpd -f ../lighttpd.config -D"
  end

  private
  def startup_script
    vars = environment_hash
    generate_startup_script(vars)
  end

  def create_lighttpd_config
    # TODO: Handle multiple instances that would share the same socket
    File.open('lighttpd.config', 'w') do |f|
      f.write <<-EOT
      server.document-root = var.CWD
      server.port = env.VMC_APP_PORT

      mimetype.assign = (
        ".html" => "text/html", 
        ".txt" => "text/plain",
        ".css" => "text/css",
        ".jpg" => "image/jpeg",
        ".png" => "image/png"
      )
      
      server.modules   += ( "mod_access", "mod_accesslog")
      index-file.names = ( "index.html", "index.php" )
      
      server.modules   += ( "mod_fastcgi" )

      ## Start an FastCGI server for php (needs the php5-cgi package)
      fastcgi.server    = ( ".php" =>
        ((
          "bin-path" => "/usr/bin/php-cgi",
          "socket" => env.HOME + "/php.socket",
          "max-procs" => 2,
          "idle-timeout" => 20,
          "bin-environment" => (
                  "PHP_FCGI_CHILDREN" => "4",
                  "PHP_FCGI_MAX_REQUESTS" => "10000"
          ),
          "bin-copy-environment" => (
                  "PATH", "SHELL", "USER", "VCAP_SERVICES"
          ),
          "broken-scriptfilename" => "enable"
        ))
      )
      
      EOT
    end
  end
end

