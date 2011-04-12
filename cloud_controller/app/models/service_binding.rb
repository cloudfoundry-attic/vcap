class ServiceBinding < ActiveRecord::Base
  belongs_to :service_config
  belongs_to :app
  belongs_to :user
  belongs_to :binding_token

  validates_presence_of :name
  validates_uniqueness_of :service_config_id, :scope => :app_id

  serialize :configuration
  serialize :credentials
  serialize :binding_options

  # Return an entry that will be stored in the :services key
  # of the staging environment.
  # The returned keys are:
  # :label, :name, :credentials, :options
  def for_staging
    data = {}
    data[:label] = service_config.service.label # what we call the offering
    data[:tags] = service_config.service.tags
    data[:name] = service_config.alias # what the user chose to name it
    data[:credentials] = credentials
    data[:options] = binding_options # options specified at bind-time
    data[:plan] = service_config.plan
    data[:plan_option] = service_config.plan_option
    data
  end
end
