require 'rubygems'
require 'json'
DEPLOYMENT_DEFAULT_SPEC = File.join("deployments", "devbox.yml")
DEPLOYMENT_DEFAULT_NAME = "devbox"
DEPLOYMENT_CONFIG_DIR_NAME = "config"
DEPLOYMENT_CONFIG_FILE_NAME = "deploy.json"
DEPLOYMENT_VCAP_CONFIG_FILE_NAME = "vcap_components.json"
DEPLOYMENT_INFO_FILE_NAME = "deployment_info.json"
DEPLOYMENT_TARGET_FILE_NAME = File.expand_path(File.join(ENV["HOME"], ".cloudfoundry_deployment_target"))
DEPLOYMENT_PROFILE_FILE_NAME = File.expand_path(File.join(ENV["HOME"], ".cloudfoundry_deployment_profile"))

class Deployment
  class << self
    def get_cloudfoundry_home
      File.expand_path(File.join(ENV["HOME"], "cloudfoundry"))
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

    def save_deployment_target(deployment_name, cloudfoundry_home)
      File.open(DEPLOYMENT_TARGET_FILE_NAME, "w") do |file|
        file.puts({"deployment_name" => deployment_name, "cloudfoundry_home" => cloudfoundry_home}.to_json)
      end
    end

    def get_deployment_target
      begin
        info = JSON.parse(File.read(DEPLOYMENT_TARGET_FILE_NAME))
        return info["deployment_name"], info["cloudfoundry_home"]
      rescue => e
        return nil
      end
    end
  end
end
