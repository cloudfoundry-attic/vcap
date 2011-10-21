require File.expand_path('../../common', __FILE__)
require 'zip/zipfilesystem'

class JavaPlugin < StagingPlugin

  def framework
    'java'
  end

  def resource_dir
    File.join(File.dirname(__FILE__), 'resources')
  end

  def stage_application
    Dir.chdir(destination_directory) do
      create_app_directories
      FileUtils.cp_r(resource_dir, destination_directory)
      FileUtils.mv(File.join(destination_directory, "resources", "droplet.yaml"), destination_directory)
      copy_source_files
      create_startup_script
    end
  end

  private
  def start_command
    config = nil
    if !File.exists?'app/app.yaml'
        #check first jar in app- TODO can do this better if app.yaml survives
        Zip::ZipFile.open(Dir.glob('app/*.jar').first) {
           |zipfile|
           config = YAML.load(zipfile.read("app.yaml"))
        }
    else
       config = YAML.load_file('app/app.yaml')
    end
    cmd = config['command']
    if cmd.start_with?("java")
       cmd = cmd.sub(/java/, "#{local_runtime} $JAVA_OPTS")
    end
    cmd
  end

  def startup_script
    vars = environment_hash
    generate_startup_script(vars)
  end
end
