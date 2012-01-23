# The priority is based upon order of creation:
# first created -> highest priority.
# Routes with asterisks should go at the end of the file if they are ambiguous.
CloudController::Application.routes.draw do
  get    'info'                      => 'default#info',         :as => :cloud_info
  get    'info/services'             => 'default#service_info', :as => :cloud_service_info
  get    'info/runtimes'             => 'default#runtime_info', :as => :cloud_runtime_info
  get    'users'                     => 'users#list',           :as => :list_users
  post   'users'                     => 'users#create',         :as => :create_user
  get    'users/*email'              => 'users#info',           :as => :user_info
  delete 'users/*email'              => 'users#delete',         :as => :delete_user
  put    'users/*email'              => 'users#update',         :as => :update_user
  post   'users/*email/tokens'       => 'user_tokens#create',   :as => :create_token
  post   'apps'                      => 'apps#create',          :as => :app_create
  get    'apps'                      => 'apps#list',            :as => :list_apps
  get    'apps/:name'                => 'apps#get',             :as => :app_get
  put    'apps/:name'                => 'apps#update',          :as => :app_update
  delete 'apps/:name'                => 'apps#delete',          :as => :app_delete

  put    'apps/:name/application'    => 'apps#upload',          :as => :app_upload
  get    'apps/:name/crashes'        => 'apps#crashes',         :as => :app_crashes
  post   'resources'                 => 'resource_pool#match',  :as => :resource_match
  get    'apps/:name/application'    => 'apps#download',        :as => :app_download
  get    'staged_droplets/:id/:hash' => 'apps#download_staged', :as => :app_download_staged
  get    'apps/:name/instances'      => 'apps#instances',       :as => :app_instances
  get    'apps/:name/stats'          => 'apps#stats',           :as => :app_stats
  get    'apps/:name/update'         => 'apps#check_update'
  put    'apps/:name/update'         => 'apps#start_update'

  #bulk APIs for health manager v.2 and billing
  #retrieving batches of items. An opaque token is returned with every request to resume the retrieval
  #from where the last request left off.
  get    'bulk/apps'                 => 'bulk#apps',            :as => :bulk_apps
  get    'bulk/users'                => 'bulk#users',           :as => :bulk_users

  # Stagers interact with the CC via these urls
  post   'staging/droplet/:id/:upload_id' => 'staging#upload_droplet', :as => :upload_droplet
  get    'staging/app/:id'                => 'staging#download_app',   :as => :download_unstaged_app

  post   'services/v1/offerings'                     => 'services#create',         :as => :service_create
  delete 'services/v1/offerings/:label'              => 'services#delete',         :as => :service_delete,         :label => /[^\/]+/
  get    'services/v1/offerings/:label/handles'      => 'services#list_handles',   :as => :service_list_handles,   :label => /[^\/]+/
  post   'services/v1/offerings/:label/handles/:id'  => 'services#update_handle',  :as => :service_update_handle,  :label => /[^\/]+/
  post   'services/v1/configurations'                => 'services#provision',      :as => :service_provision
  delete 'services/v1/configurations/:id'            => 'services#unprovision',    :as => :service_unprovision,    :id    => /[^\/]+/
  post   'services/v1/bindings'                      => 'services#bind',           :as => :service_bind
  post   'services/v1/bindings/external'             => 'services#bind_external',  :as => :service_bind_external
  delete 'services/v1/bindings/:binding_token'       => 'services#unbind',         :as => :service_unbind,         :binding_token => /[^\/]+/
  post   'services/v1/binding_tokens'                => 'binding_tokens#create',   :as => :binding_token_create
  get    'services/v1/binding_tokens/:binding_token' => 'binding_tokens#get',      :as => :binding_token_get,      :binding_token => /[^\/]+/
  delete 'services/v1/binding_tokens/:binding_token' => 'binding_tokens#delete',   :as => :binding_token_delete,   :binding_token => /[^\/]+/
  # Brokered Services
  get    'brokered_services/poc/offerings' => 'services#list_brokered_services',   :as => :service_list_brokered_services

  # Legacy services implementation (for old vmc)
  get     'services'        => 'legacy_services#list',        :as => :legacy_service_list
  post    'services'        => 'legacy_services#provision',   :as => :legacy_service_provision
  delete  'services/:alias' => 'legacy_services#unprovision', :as => :legacy_service_unprovision, :alias => /[^\/]+/
  get     'services/:alias' => 'legacy_services#get',         :as => :legacy_service_get,         :alias => /[^\/]+/
  # Not yet re-implemented
  post    'services/:label/tokens' => 'default#not_implemented'
  delete  'services/:label/tokens' => 'default#not_implemented'

  # download app files from a DEA instance
  get 'apps/:name/instances/:instance_id/files'       => 'apps#files'
  get 'apps/:name/instances/:instance_id/files/*path' => 'apps#files'

  # Index route should be last.
  root :to => "default#index"

  match '*a', :to => 'default#route_not_found'

end
