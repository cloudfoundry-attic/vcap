require File.expand_path('../../common', __FILE__)
require File.join(File.expand_path('../', __FILE__), 'virgo.rb')

class VirgoPlugin < StagingPlugin
  def framework
    'virgo'
  end

  def skip_staging webapp_root
    false
  end

  def stage_application
    Dir.chdir(destination_directory) do
      create_app_directories
      webapp_root = Virgo.prepare(destination_directory)
      copy_source_files(webapp_root)
      create_startup_script
    end
  end

  def copy_source_files(dest = nil)
    extension = Virgo.detect_file_extension(source_directory)
    dest ||= File.join(destination_directory, "app.#{extension}")
    if extension === "plan"
      system "cp -a #{File.join(source_directory, "*")} #{dest}"
      system "cp -rf #{File.join(dest, Virgo.repository, "*")} #{File.join(dest, "..", Virgo.repository)}"
      system "rm -rf #{File.join(dest, Virgo.repository)}"
    else
      output = %x[cd #{source_directory}; zip -r #{File.join(dest, File.basename(source_directory) + ".#{extension}")} *]
      raise "Could not pack Virgo application: #{output}" unless $? == 0
    end
  end

  def create_app_directories
    FileUtils.mkdir_p File.join(destination_directory, 'logs')
  end

  # The Virgo start script runs from the root of the staged application.
  def change_directory_for_start
    "cd virgo"
  end

  # We redefine this here because Virgo doesn't want to be passed the cmdline
  # args that were given to the 'start' script.
  def start_command
    "./bin/dmk.sh start -jmxport $(($PORT + 1))"
  end

  def configure_memory_opts
    # We want to set this to what the user requests, *not* set a minum bar
    "-Xms#{application_memory}m -Xmx#{application_memory}m"
  end

  private
  def startup_script
    vars = environment_hash
    vars['JAVA_OPTS'] = configure_memory_opts
    vars['JAVA_HOME'] = ENV['JAVA_HOME']
    generate_startup_script(vars) do
      <<-SPRING
export CATALINA_OPTS="$CATALINA_OPTS `ruby resources/set_environment`"
env > env.log
PORT=-1
while getopts ":p:" opt; do
  case $opt in
    p)
      PORT=$OPTARG
      ;;
  esac
done
if [ $PORT -lt 0 ] ; then
  echo "Missing or invalid port (-p)"
  exit 1
fi
ruby resources/generate_server_xml $PORT
      SPRING
    end
  end
end
