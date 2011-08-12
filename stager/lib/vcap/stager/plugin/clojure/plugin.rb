require 'fileutils'

class ClojurePlugin < StagingPlugin
  include GemfileSupport
  def framework
    'clojure'
  end

  def stage_application
    Dir.chdir(destination_directory) do
      create_app_directories
      copy_source_files
      install_leiningen
      install_deps
      create_startup_script
    end
  end

  def start_command
    return ("export HOME=`pwd`\n" +
            "export PORT=$VCAP_APP_PORT\n" + # just a convenience
            "%VCAP_LOCAL_RUNTIME% run")
  end

  private
  def startup_script
    vars = environment_hash
    generate_startup_script(vars)
  end

  def install_leiningen
    # Install a reasonable set of lein plugins along with a primed maven cache
    # into the app directory. "Reasonable" means that 99% of apps should never 
    # ever need to actually *download* anything.
    app = File.expand_path("app")
    FileUtils.cp_r(File.join(template, ".lein"), app)
    FileUtils.cp_r(File.join(template, ".m2"), app)
  end

  def template
    #XXX: this should evenually be moved to ~/.clojure-home-template
    File.expand_path("~")
  end

  def install_deps
    system("export HOME=`pwd`/app && cd app && lein deps >> ../logs/deps.log 2>&1")
  end


end

