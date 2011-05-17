class WsgiPlugin < StagingPlugin
  def framework
    'wsgi'
  end

  def stage_application
    Dir.chdir(destination_directory) do
      create_app_directories
      copy_source_files
      create_startup_script
      create_gunicorn_config
    end
  end

  def start_command
    "gunicorn -c ../gunicorn.config app:app"
  end

  private
  def startup_script
    vars = environment_hash
    generate_startup_script(vars)
  end

  def create_gunicorn_config
    File.open('gunicorn.config', 'w') do |f|
      f.write <<-EOT
import os
bind = "%s:%s" % (os.environ['VCAP_APP_HOST'], os.environ['VCAP_APP_PORT'])
      EOT
    end
  end
end
