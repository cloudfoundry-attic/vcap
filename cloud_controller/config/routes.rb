# The priority is based upon order of creation:
# first created -> highest priority.
# Routes with asterisks should go at the end of the file if they are ambiguous.
CloudController::Application.routes.draw do
  get    'info'                                 => 'default#info',         :as => :cloud_info
  get    'org/:org/info'                        => 'default#info',         :as => :cloud_org_info
  get    'org/:org/project/:project/info'       => 'default#info',         :as => :cloud_org_project_info
  get    'info/services'                        => 'default#service_info', :as => :cloud_service_info
  get    'org/:org/info/services'               => 'default#service_info', :as => :cloud_service_info
  get    'org/:org/project/:project/info/services' => 'default#service_info', :as => :cloud_service_info
  get    'info/runtimes'                        => 'default#runtime_info', :as => :cloud_runtime_info
  get    'org/:org/info/runtimes'               => 'default#runtime_info', :as => :cloud_runtime_info_for_org
  get    'org/:org/project/:project/info/runtimes'  => 'default#runtime_info', :as => :cloud_runtime_info_for_org_and_project
  get    'loginInfo'                            => 'default#login_info',   :as => :login_info
  get    'org/:org/loginInfo'                   => 'default#login_info',   :as => :cloud_org_login_info
  get    'org/:org/project/:project/loginInfo'  => 'default#login_info',   :as => :cloud_org_project_login_info
  get    'users'                                => 'users#list',           :as => :list_users
  get    'org/:org/users'                       => 'users#list',           :as => :list_users_for_org
  get    'org/:org/project/:project/users'      => 'users#list',           :as => :list_users_for_org_and_project
  post   'users'                                => 'users#create',         :as => :create_user
  get    'users/*email'                         => 'users#info',           :as => :user_info
  get    'org/:org/users/*email'                => 'users#info',           :as => :user_info_for_org
  get    'org/:org/project/:project/users/*email' => 'users#info',           :as => :user_info_for_org_and_project
  delete 'users/*email'                         => 'users#delete',         :as => :delete_user
  put    'users/*email'                         => 'users#update',         :as => :update_user
  post   'users/*email/tokens'                  => 'user_tokens#create',   :as => :create_token
  post   'org/:org/users/*email/tokens'         => 'user_tokens#create',   :as => :create_org_token
  post   'org/:org/project/:project/users/*email/tokens'       => 'user_tokens#create',   :as => :create_org_proj_token
  post   'apps'                                 => 'apps#create',          :as => :app_create
  post   'org/:org/apps'                        => 'apps#create',          :as => :app_create_for_org
  post   'org/:org/project/:project/apps'       => 'apps#create',          :as => :app_create_for_org_and_project
  get    'apps'                                 => 'apps#list',            :as => :list_apps
  get    'org/:org/apps'                        => 'apps#list',            :as => :list_apps_for_org
  get    'org/:org/project/:project/apps'       => 'apps#list',            :as => :list_apps_for_org_and_project
  get    'apps/:name'                           => 'apps#get',             :as => :app_get
  get    'org/:org/apps/:name'                  => 'apps#get',             :as => :app_get_for_org
  get    'org/:org/project/:project/apps/:name' => 'apps#get',             :as => :app_get_for_org_and_project
  put    'apps/:name'                           => 'apps#update',          :as => :app_update
  put    'org/:org/apps/:name'                  => 'apps#update',          :as => :app_update_for_org
  put    'org/:org/project/:project/apps/:name' => 'apps#update',          :as => :app_update_for_org_and_project
  delete 'apps/:name'                           => 'apps#delete',          :as => :app_delete
  delete 'org/:org/apps/:name'                  => 'apps#delete',          :as => :app_delete_for_org
  delete 'org/:org/project/:project/apps/:name' => 'apps#delete',          :as => :app_delete_for_org_and_project

  put    'apps/:name/application'             => 'apps#upload',          :as => :app_upload
  put    'org/:org/apps/:name/application'    => 'apps#upload',          :as => :app_upload_with_org
  put    'org/:org/project/:project/apps/:name/application'    => 'apps#upload',          :as => :app_upload_with_org_and_project
  get    'apps/:name/crashes'                 => 'apps#crashes',         :as => :app_crashes
  get    'org/:org/apps/:name/crashes'        => 'apps#crashes',         :as => :app_crashes_with_org
  get    'org/:org/project/:project/apps/:name/crashes'        => 'apps#crashes',         :as => :app_crashes_with_org_and_project
  post   'resources'                 => 'resource_pool#match',  :as => :resource_match
  get    'apps/:name/application'    => 'apps#download',        :as => :app_download
  get    'staged_droplets/:id/:hash' => 'apps#download_staged', :as => :app_download_staged
  get    'apps/:name/instances'      => 'apps#instances',       :as => :app_instances
  get    'apps/:name/stats'          => 'apps#stats',           :as => :app_stats
  get    'apps/:name/update'         => 'apps#check_update'
  put    'apps/:name/update'         => 'apps#start_update'

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

  # Collab spaces routes
  put    'orgs/:orgname'               => "collab_spaces#create", :as =>  :collab_spaces_create_org
  delete 'orgs/:orgname'               => "collab_spaces#delete", :as =>  :collab_spaces_delete_org

  # Index route should be last.
  get   'org/:org'                  => "default#index"
  get   'org/:org/project/:project' => "default#index"
  root :to                           => "default#index"

  match '*a', :to => 'default#route_not_found'


end
