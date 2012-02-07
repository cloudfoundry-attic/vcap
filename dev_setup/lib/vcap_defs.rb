require 'rubygems'
require 'json'

module VcapStringExtensions

  def red
    colorize("\e[0m\e[31m")
  end

  def green
    colorize("\e[0m\e[32m")
  end

  def yellow
    colorize("\e[0m\e[33m")
  end

  def bold
    colorize("\e[0m\e[1m")
  end

  def colorize(color_code)
    unless $nocolor
      "#{color_code}#{self}\e[0m"
    else
      self
    end
  end
end

class String
  include VcapStringExtensions
end

DEPLOYMENT_DEFAULT_SPEC = File.join("deployments", "devbox.yml")
DEPLOYMENT_DEFAULT_NAME = "devbox"
DEPLOYMENT_DEFAULT_DOMAIN = "vcap.me"
DEPLOYMENT_CONFIG_DIR_NAME = "config"
DEPLOYMENT_CONFIG_FILE_NAME = "deploy.json"
DEPLOYMENT_VCAP_CONFIG_FILE_NAME = "vcap_components.json"
DEPLOYMENT_INFO_FILE_NAME = "deployment_info.json"
DEPLOYMENT_TARGET_FILE_NAME = File.expand_path(File.join(ENV["HOME"], ".cloudfoundry_deployment_target"))
DEPLOYMENT_PROFILE_FILE_NAME = File.expand_path(File.join(ENV["HOME"], ".cloudfoundry_deployment_profile"))
DEPLOYMENT_LOCAL_RUN_PROFILE_FILE_NAME = File.expand_path(File.join(ENV["HOME"], ".cloudfoundry_deployment_local"))

class Deployment
  class << self
    def get_cloudfoundry_home
      File.expand_path(File.join(ENV["HOME"], "cloudfoundry"))
    end

    def get_cloudfoundry_domain
      DEPLOYMENT_DEFAULT_DOMAIN
    end

    def get_config_path(name, cloudfoundry_home=nil)
      cloudfoundry_home ||= get_cloudfoundry_home
      File.expand_path(File.join(cloudfoundry_home, ".deployments", name, DEPLOYMENT_CONFIG_DIR_NAME))
    end

    def get_config_file(config_path)
      File.expand_path(File.join(config_path, DEPLOYMENT_CONFIG_FILE_NAME))
    end

    def get_vcap_config_file(config_path)
      File.expand_path(File.join(config_path, DEPLOYMENT_VCAP_CONFIG_FILE_NAME))
    end

    def get_deployment_info_file(config_path)
      File.expand_path(File.join(config_path, DEPLOYMENT_INFO_FILE_NAME))
    end

    def get_deployment_profile_file
      DEPLOYMENT_PROFILE_FILE_NAME
    end

    def get_local_deployment_run_profile
      DEPLOYMENT_LOCAL_RUN_PROFILE_FILE_NAME
    end

    def save_deployment_target(deployment_name, cloudfoundry_home)
      File.open(DEPLOYMENT_TARGET_FILE_NAME, "w") do |file|
        file.puts({"deployment_name" => deployment_name, "cloudfoundry_home" => cloudfoundry_home}.to_json)
      end
    end

    def get_deployment_target
      begin
        info = JSON.parse(File.read(DEPLOYMENT_TARGET_FILE_NAME))
        [ info["deployment_name"], info["cloudfoundry_home"] ]
      rescue => e
      end
    end
  end
end
