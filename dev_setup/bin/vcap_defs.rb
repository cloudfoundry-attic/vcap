DEPLOYMENT_DEFAULT_SPEC = "deployments/devbox.yml.erb"
DEPLOYMENT_DEFAULT_NAME = "devbox"
DEPLOYMENT_CONFIG_DIR_NAME = "config"
DEPLOYMENT_CONFIG_FILE_NAME = "deploy.json"

module Deployment
  def Deployment.get_home(name)
    File.expand_path(File.join(ENV["HOME"], ".cloudfoundry", name))
  end

  def Deployment.get_config_path(home)
    File.expand_path(File.join(home, DEPLOYMENT_CONFIG_DIR_NAME))
  end

  def Deployment.get_cfg_file(cfg_path)
    File.expand_path(File.join(cfg_path, DEPLOYMENT_CONFIG_FILE_NAME))
  end
end
