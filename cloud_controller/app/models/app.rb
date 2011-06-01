require 'set'
require 'services/api'
require 'openssl'

class App < ActiveRecord::Base
  belongs_to :owner, :class_name => 'User' # By default, whomever created the app
  has_many :app_collaborations, :dependent => :destroy
  has_many :collaborators, :through => :app_collaborations, :source => :user
  has_many :service_bindings, :dependent => :destroy
  has_many :service_configs, :through => :service_bindings
  has_many :routes, :dependent => :destroy

  before_validation :normalize_legacy_staging_strings!

  after_create :add_owner_as_collaborator

  scope :started, lambda { where("apps.state = ?", 'STARTED') }
  scope :stopped, lambda { where("apps.state = ?", 'STOPPED') }

  AppStates = %w[STOPPED STARTED]
  PackageStates = %w[PENDING STAGED FAILED]
  Runtimes = %w[ruby18 ruby19 java node erlangR14B02]
  Frameworks = %w[sinatra rails3 spring grails node otp_rebar lift unknown]

  validates_presence_of :name, :framework, :runtime

  validates_format_of :name, :with => /^[\w-]+$/ # Don't allow periods, !, etc

  # TODO - Update vmc client to use reasonable strings for these.
  validates_inclusion_of :framework, :in => Frameworks
  validates_inclusion_of :runtime, :in => Runtimes
  validates_inclusion_of :state, :in => AppStates
  validates_inclusion_of :package_state, :in => PackageStates

  def self.find_by_collaborator_and_id(user, app_id)
    App.joins(:app_collaborations).where(:app_collaborations => {:user_id => user.id}, :apps => {:id => app_id}).first
  end

  def self.process_health_manager_message(decoded_json)
    if decoded_json && app_id = decoded_json[:droplet]
      if app = App.find_by_id(app_id)
        AppManager.new(app).health_manager_message_received(decoded_json)
      elsif decoded_json[:op] =~ /STOP/i
        # App no longer exists, so we might as well tell it to stop
        NATS.publish('dea.stop', Yajl::Encoder.encode(:droplet => app_id))
      end
    end
  end

  # Called by the Health Manager when it wants to refresh from the database.
  def self.health_manager_representations
    results = []
    emails_by_id = {}
    users = ::User.find(connection.select_values("select owner_id from apps"))
    users.each {|u| emails_by_id[u.id.to_s] = u.email}
    apps = connection.select_all("select id, name, state, instances, owner_id from apps")
    apps.each do |row|
      h = {:droplet_id => row['id'].to_i, :state => row['state'], :name => row['name']}
      h[:user] = emails_by_id[row['owner_id']]
      h[:instances] = row['instances'].to_i
      results << h
    end
    results
  end

  def self.health(request)
    return {} if request.empty?
    message = { :droplets => request }.to_json

    result = {}
    opts = { :timeout => 1, :expected => request.length }
    droplet_health = NATS.timed_request('healthmanager.health', message, opts)

    droplet_health.each do |payload|
      payload_json = Yajl::Parser.parse(payload, :symbolize_keys => true)
      result[payload_json[:droplet]] = payload_json[:healthy]
    end
    result
  end

  def total_memory
    instances * memory
  end

  def as_json(options = nil)
    { :name => name,
      :staging => {:model => framework, :stack => runtime},
      :uris => mapped_urls,
      :instances => instances,
      :runningInstances => running_instances,
      :resources => resource_requirements,
      :state => state.upcase,
      :services => bound_services,
      :version => generate_version,
      :env => environment,
      :meta => {:version => lock_version, :created => Time.now.to_i} }
  end

  # Called by AppManager when staging this app.
  def staging_environment
    Yajl::Encoder.encode(staging_environment_data)
  end

  # The data that is passed to the staging plugin for this app.
  def staging_environment_data
    # each ServiceBinding returns a denormalized configuration.
    services = service_bindings(true).map {|sb| sb.for_staging}
    { :services => services,
      :framework => framework,
      :runtime => runtime,
      :resources => resource_requirements }
  end

  # Returns an array of the URLs that point to this application
  def mapped_urls
    routes.active.map {|r| r.url}.sort
  end

  def running_instances
    return 0 unless started?
    # If started, poll for correct running_instances through the HM
    h = ::App.health([{ :droplet => self.id, :version => generate_version }])
    h ? h[self.id] : 0
  end

  def resource_requirements
    {:memory => memory, :disk => disk_quota, :fds => file_descriptors}
  end

  def limits
    {:mem => memory, :disk => disk_quota, :fds => file_descriptors}
  end

  # Returns an array of 'VARNAME=value' strings that should be exported
  # into the environment for this app.
  def environment_variables
    vars = environment
    vars.concat(proxy_environment)
    vars.uniq
  end

  def proxy_environment
    env = []
    ["HTTP_PROXY", "HTTPS_PROXY", "NO_PROXY"].each do |name|
      # Assumes that HTTP_PROXY and http_proxy are set to the same value
      value = ENV[name] || ENV[name.downcase]
      if value
        env << "#{name}='#{value}'"
        env << "#{name.downcase}='#{value}'"
      end
    end
    env
  end

  def bound_services
    service_configs.map {|sc| sc.alias }
  end

  def diff_configs(binding_names)
    given = Set.new(binding_names)
    current = Set.new(service_configs.map {|sc| sc.alias})

    inter = current & given
    added = given - inter
    removed = current - inter

    [added.to_a, removed.to_a]
  end

  def bind_to_config(cfg, binding_options={})
    svc = cfg.service

    # The ordering here is odd, but important; it allows us to repair our internal
    # state to match that of the gateway. The description following each operation
    # assumes that the operation has failed.
    #
    # 1. Create a binding token.
    #    Nothing has been added to our db or the service provider. All is well.
    #
    # 2. Issue the request upstream.
    #    a. Delete the binding token
    #       We can detect and reap dangling binding tokens using a background job.
    #
    # 3. Create the service binding
    #    a. Delete the binding token
    #       Same as 2a
    #    The service gateway must delete the binding the next time it pulls the canonical
    #    state from us.

    tok = ::BindingToken.generate(
      :label => svc.label,
      :binding_options => binding_options,
      :service_config  => cfg,
      :auto_generated  => true
    )
    tok.save!

    begin
      req = VCAP::Services::Api::GatewayBindRequest.new(
        :service_id => cfg.name,
        :label      => svc.label,
        :binding_options => binding_options
      )

      if EM.reactor_running?
        # yields
        endpoint = "#{svc.url}/gateway/v1/configurations/#{req.service_id}/handles"
        http = VCAP::Services::Api::AsyncHttpRequest.fibered(endpoint, svc.token, :post, req)
        if !http.error.empty?
          raise "Error sending bind request #{req.extract.inspect} to gateway #{svc.url}: #{http.error}"
        elsif http.response_header.status != 200
          raise "Error sending bind request #{req.extract.inspect}, non 200 response from gateway #{svc.url}: #{http.response_header.status} #{http.response}"
        end
        handle = VCAP::Services::Api::GatewayBindResponse.decode(http.response)
      else
        uri = URI.parse(svc.url)
        gw = VCAP::Services::Api::ServiceGatewayClient.new(uri.host, svc.token, uri.port)
        handle = gw.bind(req.extract)
      end
    rescue => e
      logger.error("Exception talking to gateway: #{e}")
      tok.destroy
      raise CloudError.new(CloudError::SERVICE_GATEWAY_ERROR)
    end

    begin
      bdg = ::ServiceBinding.new(
        :app_id          => self.id,
        :user            => self.owner,
        :name            => handle.service_id,
        :service_config  => cfg,
        :binding_token   => tok,
        :configuration   => handle.configuration,
        :credentials     => handle.credentials,
        :binding_options => binding_options
      )
      bdg.save!
    rescue => e
      tok.destroy
      raise e
    end

    bdg
  end

  def unbind_from_config(cfg)

    # It's possible that a previous attempt at binding failed, leaving a dangling token.
    # In this case just log the issue and clean up.

    binding = ::ServiceBinding.find_by_service_config_id_and_app_id(cfg.id, self.id)
    raise CloudError.new(CloudError::BINDING_NOT_FOUND) unless binding
    tok = binding.binding_token
    svc = cfg.service

    # Ordering is important. The description that follows each operation assumes
    # that the operation has failed.
    #
    # 1. Destroy our copy of the binding.
    #    No state has been changed. All is well.
    #
    # 2. Issue the request upstream.
    #    The upstream gateway is responsible for deleting the binding the next time it
    #    pulls the canonical state from us. We can reap the dangling binding token
    #    with a background process (find all auto-created tokens with no associated binding).
    #
    # 3. Delete the binding token
    #    Reap the dangling tokens as in 2.

    req = VCAP::Services::Api::GatewayUnbindRequest.new(
      :service_id      => cfg.name,
      :handle_id       => binding.name,
      :binding_options => binding.binding_options
    )

    binding.destroy

    begin
      if EM.reactor_running?
        endpoint = "#{svc.url}/gateway/v1/configurations/#{req.service_id}/handles/#{req.handle_id}"
        http = VCAP::Services::Api::AsyncHttpRequest.new(endpoint, svc.token, :delete, req)
        http.callback do
          if http.response_header.status != 200
            logger.error("Error sending unbind request #{req.extract.to_json} non 200 response from gateway #{svc.url}: #{http.response_header.status} #{http.response}")
          end
        end
        http.errback do
          logger.error("Error sending unbind request #{req.extract.to_json} to gateway #{svc.url}: #{http.error}")
        end
      else
        uri = URI.parse(svc.url)
        gw = VCAP::Services::Api::ServiceGatewayClient.new(uri.host, svc.token, uri.port)
        gw.unbind(req.extract)
      end
    rescue => e
      tok.destroy
      logger.error("Error talking to service gateway (svc.url): #{e.to_s}")
      raise CloudError.new(CloudError::SERVICE_GATEWAY_ERROR)
    end
    tok.destroy
  end

  def purge_droplets
    # Clean up the packages/droplets
    unless self.package_hash.nil?
      app_package = File.join(AppPackage.package_dir, self.package_hash)
      FileUtils.rm_f(app_package)
    end
    unless self.staged_package_hash.nil?
      staged_package = File.join(AppPackage.package_dir, self.staged_package_hash)
      FileUtils.rm_f(staged_package)
    end
  end

  # TODO - By the time this method returns, it should be safe to delete this app.
  def purge_all_resources!
    AppManager.new(self).stopped
    purge_droplets
  end

  # Passed an instance of AppPackage.
  # We don't want this to block, so mark as pending and schedule work.
  def latest_bits_from(app_package)
    zipfile_path = app_package.to_zip # resulting filename is the SHA1 of the file.
    sha1 = File.basename(zipfile_path)
    # We are not pending if the bits have not changed.
    unless package_hash == sha1
      # Remove old one
      unless self.package_hash.nil?
        app_package = File.join(AppPackage.package_dir, self.package_hash)
        FileUtils.rm_f(app_package)
      end
      self.package_state = 'PENDING'
      self.package_hash = sha1
      save!
    end
  end

  def metadata
    json = read_attribute(:metadata_json)
    return {} if json.blank?
    Yajl::Parser.parse(json, :symbolize_keys => true)
  end

  def metadata=(hash)
    write_attribute(:metadata_json, Yajl::Encoder.encode(hash))
  end

  def environment
    json_crypt = read_attribute(:environment_json)
    return [] if json_crypt.blank?
    e = json_crypt.unpack('m*')[0]
    d = OpenSSL::Cipher::Cipher.new('blowfish')
    d.decrypt
    d.key = AppConfig[:keys][:password]
    json = d.update(e)
    json << d.final
    Yajl::Parser.parse(json)
  end

  def environment=(array)
    json = Yajl::Encoder.encode(array)
    c = OpenSSL::Cipher::Cipher.new('blowfish')
    c.encrypt
    c.key = AppConfig[:keys][:password]
    json_crypt = c.update(json)
    json_crypt << c.final
    write_attribute(:environment_json, [json_crypt].pack('m0').gsub("\n",''))
  end

  # URL limits are checked in apps_controller; by the time this is called, you should
  # be sure that the app owner is allowed to have this many URLs.
  # Returns whether or not the url set was changed and needs to be sent out to DEAs.
  def set_urls(urls)
    raise ActiveRecord::RecordInvalid, "unsaved apps can not have URLs" if new_record?

    # We don't need to do anything if nothing has changed. This avoids excess dea.update messages.
    current_urls = routes.collect { |r| r.url if r.active }
    urls.sort!
    current_urls.sort!
    return false if urls == current_urls

    if urls.nil? || urls.blank?
      routes.clear
    elsif Array === urls
      seen = []
      urls.each do |url|
        if route = mapped_to_url?(url)
          route.update_attribute(:active, true) unless route.active?
          seen.push(route)
        else
          route = add_url(url)
          seen.push(route)
        end
      end
      routes.each do |existing_route|
        existing_route.destroy unless seen.include?(existing_route)
      end
    end
    save!
    true
  end

  def mapped_to_url?(url)
    url = url.to_s
    routes.detect {|r| r.url == url}
  end

  def add_url(url)
    route = routes.build(:url => url, :active => true)
    raise CloudError.new(CloudError::URI_NOT_ALLOWED) unless route.allowed?

    if route.save
      routes(true)
      route
    else
      raise CloudError.new(CloudError::URI_ALREADY_TAKEN, url)
    end
  end

  def started?
    state == 'STARTED'
  end

  def stopped?
    state == 'STOPPED'
  end

  def pending?
    self.package_state == 'PENDING'
  end

  def staged?
    self.package_state == 'STAGED'
  end

  def staging_failed?
    self.package_state == 'FAILED'
  end

  def needs_staging?
    !(self.package_hash.blank? || self.staged?)
  end

  def find_recent_crashes
    AppManager.new(self).find_crashes
  end

  def find_instances
    AppManager.new(self).find_instances
  end

  def staged_package_path
    if staged_package_hash
      File.join(AppPackage.package_dir, staged_package_hash)
    end
  end

  def unstaged_package_path
    if package_hash
      File.join(AppPackage.package_dir, package_hash)
    end
  end

  def explode_into(exploded_dir)
    zipfile = File.join(AppPackage.package_dir, package_hash)
    cmd = "unzip -q -d #{exploded_dir} #{zipfile}"
    if system(cmd)
      yield exploded_dir if block_given?
    else
      raise "Unable to unpack upload from #{zipfile}"
    end
    exploded_dir
  end

  def last_updated
    updated_at.to_i
  end

  def generate_version
    version = staged_package_hash || package_hash || VCAP.fast_uuid
    "#{version}-#{run_count}"
  end

  def restage
    self.package_state = 'PENDING'
    AppManager.new(self).stage
  end

  def collaborator?(user)
    (AppCollaboration.find_by_user_id_and_app_id(user.id, self.id) ? true : false)
  end

  def add_collaborator(user)
    App.transaction do
      collab = AppCollaboration.new(:user => user, :app => self)
      self.app_collaborations << collab
      collab.save!
      self.save!
    end
  end

  def remove_collaborator(user)
    collab = AppCollaboration.find_by_app_id_and_user_id(self.id, user.id)
    collab.destroy if collab
  end

  private

  # TODO - Remove this when the VMC client has been updated to match our new strings.
  def normalize_legacy_staging_strings!
    case framework
    when "http://b20nine.com/unknown"
      self.framework = 'sinatra'
      self.runtime   = 'ruby18'
    when "nodejs/1.0"
      self.framework = 'node'
      self.runtime   = 'node'
    when "rails/1.0"
      self.framework = 'rails3'
      self.runtime   = 'ruby18'
    when "spring_web/1.0"
      self.framework = 'spring'
      self.runtime   = 'java'
    when "grails/1.0"
      self.framework = 'grails'
      self.runtime   = 'java'
    when "lift/1.0"
      self.framework = 'lift'
      self.runtime   = 'java'
    end
    self.runtime = StagingPlugin.default_runtime_for(framework) if self.runtime.nil?
    true
  end

  def add_owner_as_collaborator
    ac = AppCollaboration.new(:user_id => self.owner_id, :app_id => self.id)
    ac.save!
  end
end

