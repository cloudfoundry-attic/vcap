require 'spec_helper'

require 'mocha'
require 'thin'
require 'uri'

# Shim so that we can stub/mock out desired return values for our forked
# gateway
class ServiceProvisionerStub
  def provision_service(version, plan)
  end

  def unprovision_service(service_id)
  end

  def bind_instance(service_id, binding_options)
  end

  def unbind_instance(service_id, handle_id, binding_options)
  end
end

describe ServicesController do

  describe "Gateway facing apis" do
    before :each do
      request.env['CONTENT_TYPE'] = Mime::JSON
      request.env['HTTP_ACCEPT'] = Mime::JSON
      request.env['HTTP_X_VCAP_SERVICE_TOKEN'] = 'foobar'
    end

    describe '#create' do

      it 'should reject requests without auth tokens' do
        request.env.delete 'HTTP_X_VCAP_SERVICE_TOKEN'
        post :create
        response.status.should == 403
      end

      it 'should should reject posts with malformed bodies' do
        request.env['RAW_POST_DATA'] = 'foobar'
        post :create
        response.status.should == 400
      end

      it 'should reject requests with missing parameters' do
        request.env['RAW_POST_DATA'] = '{}'
        post :create
        response.status.should == 400
      end

      it 'should reject requests with invalid parameters' do
        request.env['RAW_POST_DATA'] = {:label => 'foobar', :url => 'zazzle'}.to_json
        post :create
        response.status.should == 400
      end

      it 'should create service offerings for builtin services' do
        AppConfig[:builtin_services][:foo] = {:token => 'foobar'}
        post_msg :create do
          VCAP::Services::Api::ServiceOfferingRequest.new(
            :label => 'foo-bar',
            :url   => 'http://www.google.com')
        end
        AppConfig[:builtin_services].delete(:foo)
        response.status.should == 200
      end

      it 'should create service offerings for brokered service' do
        request.env['HTTP_X_VCAP_SERVICE_TOKEN'] = 'broker'
        AppConfig[:service_broker] = {:token => 'broker'}
        post_msg :create do
          VCAP::Services::Api::ServiceOfferingRequest.new(
            :label => 'foo-bar',
            :url   => 'http://localhost:56789')
        end
        response.status.should == 200
      end

      it 'should not create brokered service offerings if token mismatch' do
        request.env['HTTP_X_VCAP_SERVICE_TOKEN'] = 'foobar'
        AppConfig[:service_broker] = {:token => 'broker'}
        post_msg :create do
          VCAP::Services::Api::ServiceOfferingRequest.new(
            :label => 'foo-bar',
            :url   => 'http://localhost:56789')
        end
        response.status.should == 403
      end

      it 'should not create service offerings if not builtin' do
        post_msg :create do
          VCAP::Services::Api::ServiceOfferingRequest.new(
            :label => 'foo-bar',
            :url => 'http://www.google.com',
            :plans => ['foo'])
        end
        response.status.should == 403
      end

      it 'should update existing offerings' do
        acls = {
          'users' => ['foo@bar.com'],
          'wildcards' => ['*@foo.com'],
        }
        svc = Service.create(
          :label => 'foo-bar',
          :url   => 'http://www.google.com',
          :token => 'foobar',
          :plans => ['foo'])
        svc.should be_valid

        post_msg :create do
          VCAP::Services::Api::ServiceOfferingRequest.new(
            :label => 'foo-bar',
            :url   => 'http://www.google.com',
            :acls  => acls,
            :plans => ['foo'],
            :timeout => 20,
            :description => 'foobar')
        end
        response.status.should == 200
        svc = Service.find_by_label('foo-bar')
        svc.should_not be_nil
        svc.description.should == 'foobar'
        svc.timeout.should == 20
      end


      it 'should support reverting existing offerings to nil' do
        acls = {
          'users' => ['foo@bar.com'],
          'wildcards' => ['*@foo.com'],
        }
        svc = Service.create(
          :label => 'foo-bar',
          :url   => 'http://www.google.com',
          :token => 'foobar',
          :acls  => acls,
          :timeout => 20,
          :plans => ['foo'])
        svc.should be_valid

        post_msg :create do
          VCAP::Services::Api::ServiceOfferingRequest.new(
            :label => 'foo-bar',
            :url   => 'http://www.google.com',
            :plans => ['foo'],
            :description => 'foobar')
        end
        response.status.should == 200
        svc = Service.find_by_label('foo-bar')
        svc.should_not be_nil
        svc.timeout.should be_nil
        svc.acls.should be_nil
      end

      it 'should return not authorized on token mismatch for non builtin services' do
        svc = Service.create(
          :label => 'foo-bar',
          :url   => 'http://www.google.com',
          :token => 'foobar')
        svc.should be_valid

        request.env['HTTP_X_VCAP_SERVICE_TOKEN'] = 'barfoo'
        post_msg :create do
          VCAP::Services::Api::ServiceOfferingRequest.new(
            :label => 'foo-bar',
            :plans => ['foo'],
            :url   => 'http://www.google.com')
        end
        response.status.should == 403
      end

      it 'should return not authorized on token mismatch for builtin services' do
        AppConfig[:builtin_services][:foo] = {:token => 'foobar'}
        post_msg :create do
          VCAP::Services::Api::ServiceOfferingRequest.new(
            :label => 'foo-bar',
            :url   => 'http://www.google.com')
        end
        response.status.should == 200
        request.env['HTTP_X_VCAP_SERVICE_TOKEN'] = 'barfoo'
        post_msg :create do
          VCAP::Services::Api::ServiceOfferingRequest.new(
            :label => 'foo-bar',
            :plans => ['foo'],
            :url   => 'http://www.google.com')
        end
        response.status.should == 403
        AppConfig[:builtin_services].delete(:foo)
      end
    end

    describe '#delete' do
      before :each do
        @svc = Service.create(
          :label => 'foo-bar',
          :url   => 'http://www.google.com',
          :token => 'foobar')
        @svc.should be_valid
      end

      it 'should return not found for unknown services' do
        delete :delete, :label => 'xxx'
        response.status.should == 404
      end

      it 'should return not authorized on token mismatch' do
        request.env['HTTP_X_VCAP_SERVICE_TOKEN'] = 'barfoo'
        delete :delete, :label => 'foo-bar'
        response.status.should == 403
      end

      it 'should delete existing offerings' do
        delete :delete, :label => 'foo-bar'
        response.status.should == 200

        svc = Service.find_by_label('foo-bar')
        svc.should be_nil
      end
    end

    describe '#list_handles' do
      it 'should return not found for unknown services' do
        get :list_handles, :label => 'foo-bar'
        response.status.should == 404
      end

      it 'should return provisioned and bound handles' do
        svc = Service.new
        svc.label = "foo-bar"
        svc.url   = "http://localhost:56789"
        svc.token = 'foobar'
        svc.save
        svc.should be_valid

        cfg = ServiceConfig.new(:name => 'foo', :alias => 'bar', :service => svc)
        cfg.save
        cfg.should be_valid

        bdg = ServiceBinding.new(
          :name  => 'xxxxx',
          :service_config  => cfg,
          :configuration   => {},
          :credentials     => {},
          :binding_options => []
        )
        bdg.save
        bdg.should be_valid

        get :list_handles, :label => 'foo-bar'
        response.status.should == 200
      end
    end

    describe '#list_brokered_services' do
      before :each do
        request.env['HTTP_X_VCAP_SERVICE_TOKEN'] = 'broker'
        AppConfig[:service_broker] = {:token => 'broker'}
      end

      it "should return not authorized on token mismatch" do
        request.env['HTTP_X_VCAP_SERVICE_TOKEN'] = 'foobar'
        get :list_brokered_services
        response.status.should == 403
      end

      it "should not list builtin services" do
        AppConfig[:builtin_services] = {
          :foo => {:token=>"foobar"}
        }
        svc = Service.new
        svc.label = "foo-1.0"
        svc.url   = "http://localhost:56789"
        svc.token = 'foobar'
        svc.save
        svc.should be_valid

        get :list_brokered_services
        response.status.should == 200
        Yajl::Parser.parse(response.body)['brokered_services'].should be_empty
      end

      it "should list brokered services" do
        AppConfig[:builtin_services] = {
          :foo => {:token=>"foobar"}
        }

        svc = Service.new
        svc.label = "brokered-1.0"
        svc.url   = "http://localhost:56789"
        svc.token = 'brokered'
        svc.save
        svc.should be_valid

        get :list_brokered_services
        response.status.should == 200
        Yajl::Parser.parse(response.body)['brokered_services'].size.should == 1
      end
    end

    describe '#update_handle' do
      before :each do
        svc = Service.new
        svc.label = "foo-bar"
        svc.url   = "http://localhost:56789"
        svc.token = 'foobar'
        svc.save
        svc.should be_valid
        @svc = svc

        cfg = ServiceConfig.new(:name => 'foo', :alias => 'bar', :service => svc)
        cfg.save
        cfg.should be_valid
        @cfg = cfg

        bdg = ServiceBinding.new(
          :name  => 'xxxxx',
          :service_config  => cfg,
          :configuration   => {},
          :credentials     => {},
          :binding_options => []
        )
        bdg.save
        bdg.should be_valid
        @bdg = bdg
      end

      it 'should return not found for unknown handles' do
        post_msg :update_handle, :label => @svc.label, :id => 'xxx' do
          VCAP::Services::Api::HandleUpdateRequest.new(
             :service_id => 'xxx',
             :configuration => [],
             :credentials   => []
          )
        end
        response.status.should == 404
      end

      it 'should update provisioned handles' do
        post_msg :update_handle, :label => @svc.label, :id => @cfg.name do
          VCAP::Services::Api::HandleUpdateRequest.new(
             :service_id => @cfg.name,
             :configuration => [],
             :credentials   => []
          )
        end
        response.status.should == 200
      end

      it 'should update bound handles' do
        post_msg :update_handle, :label => @svc.label, :id => @bdg.name do
          VCAP::Services::Api::HandleUpdateRequest.new(
             :service_id => @bdg.name,
             :configuration => ['foo'],
             :credentials   => ['bar']
          )
        end
        foo = ServiceBinding.find_by_name(@bdg.name)
        response.status.should == 200
      end
    end
  end

  describe "User facing apis" do
    before :each do
      u = User.new(:email => 'foo@bar.com')
      u.set_and_encrypt_password('foobar')
      u.save
      u.should be_valid
      @user = u

      a = App.new(
        :owner => u,
        :name => 'foobar',
        :framework => 'sinatra',
        :runtime => 'ruby18')
      a.save
      a.should be_valid
      @app = a

      svc = Service.new
      svc.label = "foo-bar"
      svc.url   = "http://localhost:56789"
      svc.token = 'foobar'
      svc.save
      svc.should be_valid
      @svc = svc

      request.env['CONTENT_TYPE'] = Mime::JSON
      request.env['HTTP_AUTHORIZATION'] = UserToken.create('foo@bar.com').encode
    end

    describe '#provision' do

      it 'should return not authorized for unknown users' do
        request.env['HTTP_AUTHORIZATION'] = UserToken.create('bar@foo.com').encode
        post :provision
        response.status.should == 403
      end

      it 'should return not found for unknown services' do
        post_msg :provision do
          VCAP::Services::Api::CloudControllerProvisionRequest.new(
            :label => 'bar-foo',
            :name  => 'foo',
            :plan  => 'free')
        end
        response.status.should == 404
      end

      it 'should provision services' do
        shim = ServiceProvisionerStub.new
        shim.stubs(:provision_service).returns({:data => {}, :service_id => 'foo', :credentials => {}})
        gw_pid = start_gateway(@svc, shim)
        post_msg :provision do
          VCAP::Services::Api::CloudControllerProvisionRequest.new(
            :label => 'foo-bar',
            :name  => 'foo',
            :plan  => 'free')
        end
        response.status.should == 200
        stop_gateway(gw_pid)
      end

      it 'should fail to provision a config with the same name as an existing config' do
        shim = ServiceProvisionerStub.new
        shim.stubs(:provision_service).returns({:data => {}, :service_id => 'foo', :credentials => {}})
        gw_pid = start_gateway(@svc, shim)

        post_msg :provision do
          VCAP::Services::Api::CloudControllerProvisionRequest.new(
            :label => 'foo-bar',
            :name  => 'foo',
            :plan  => 'free')
        end
        response.status.should == 200

        post_msg :provision do
          VCAP::Services::Api::CloudControllerProvisionRequest.new(
            :label => 'foo-bar',
            :name  => 'foo',
            :plan  => 'free')
        end
        response.status.should == 400

        stop_gateway(gw_pid)
      end
    end

    describe "#bind" do
      before :each do
        cfg = ServiceConfig.new(:name => 'foo', :alias => 'bar', :service => @svc, :user => @user)
        cfg.save
        cfg.should be_valid
        @cfg = cfg
      end

      it 'should return not authorized for unknown users' do
        request.env['HTTP_AUTHORIZATION'] = UserToken.create('bar@foo.com').encode
        post :bind
        response.status.should == 403
      end

      it 'should return not found for unknown apps' do
        post_msg :bind do
          VCAP::Services::Api::CloudControllerBindRequest.new(
            :app_id          => 1234,
            :service_id      => 'xxx',
            :binding_options => []
          )
        end
        response.status.should == 404
      end

      it 'should return not found for unknown service configs' do
        post_msg :bind do
          VCAP::Services::Api::CloudControllerBindRequest.new(
            :app_id          => @app.id,
            :service_id      => 'xxx',
            :binding_options => []
          )
        end
        response.status.should == 404
      end

      it 'should successfully bind a known config to a known app' do
        shim = ServiceProvisionerStub.new
        shim.stubs(:bind_instance).returns({:configuration => {}, :service_id => 'foo', :credentials => {}})
        gw_pid = start_gateway(@svc, shim)
        post_msg :bind do
          VCAP::Services::Api::CloudControllerBindRequest.new(
            :service_id      => @cfg.name,
            :app_id          => @app.id,
            :binding_options => ['foo']
          )
        end
        response.status.should == 200
        binding = ServiceBinding.find_by_user_id_and_app_id(@user.id, @app.id)
        binding.should_not be_nil
        stop_gateway(gw_pid)
      end
    end

    describe "#bind_external" do
      before :each do
        cfg = ServiceConfig.new(:name => 'foo', :alias => 'bar', :service => @svc, :user => @user)
        cfg.save
        cfg.should be_valid
        @cfg = cfg

        tok = BindingToken.generate(:label => 'foo', :service_config => cfg, :binding_options => ['free'])
        tok.save
        tok.should be_valid
        @tok = tok
      end

      it 'should return not authorized for unknown users' do
        request.env['HTTP_AUTHORIZATION'] = UserToken.create('bar@foo.com').encode
        post :bind_external
        response.status.should == 403
      end

      it 'should return not found for unknown tokens' do
        post_msg :bind_external do
          VCAP::Services::Api::BindExternalRequest.new(
            :app_id        => @app.id,
            :binding_token => 'xxx'
          )
        end
        response.status.should == 404
      end

      it 'should return not found for unknown apps' do
        post_msg :bind_external do
          VCAP::Services::Api::BindExternalRequest.new(
            :app_id        => 1234,
            :binding_token => @tok.uuid
          )
        end
        response.status.should == 404
      end

      it 'should successfully bind a known token to a known app' do
        shim = ServiceProvisionerStub.new
        shim.stubs(:bind_instance).returns({:configuration => {}, :service_id => 'foo', :credentials => {}})
        gw_pid = start_gateway(@svc, shim)
        post_msg :bind_external do
          VCAP::Services::Api::BindExternalRequest.new(
            :app_id        => @app.id,
            :binding_token => @tok.uuid
          )
        end
        response.status.should == 200
        binding = ServiceBinding.find_by_user_id_and_app_id(@user.id, @app.id)
        binding.should_not be_nil
        stop_gateway(gw_pid)
      end
    end

    describe "#unbind" do
      before :each do
        cfg = ServiceConfig.new(:name => 'foo', :alias => 'bar', :service => @svc, :user => @user)
        cfg.save
        cfg.should be_valid
        @cfg = cfg

        tok = BindingToken.generate(
          :label => 'foo-bar',
          :binding_options => [],
          :service_config => @cfg
        )
        tok.save
        tok.should be_valid
        @tok = tok

        bdg = ServiceBinding.new(
          :app   => @app,
          :user  => @user,
          :name  => 'xxxxx',
          :service_config  => @cfg,
          :configuration   => {},
          :credentials     => {},
          :binding_options => [],
          :binding_token   => @tok
        )
        bdg.save
        bdg.should be_valid
        @bdg = bdg
      end

      it 'should return not authorized for unknown users' do
        request.env['HTTP_AUTHORIZATION'] = UserToken.create('bar@foo.com').encode
        delete :unbind, :binding_token => 'xxx'
        response.status.should == 403
      end

      it 'should return not found for unknown bindings' do
        delete :unbind, :binding_token => 'xxx'
        response.status.should == 404
      end

      it 'should successfully delete known bindings' do
        shim = ServiceProvisionerStub.new
        shim.stubs(:unbind_instance).returns(true)
        gw_pid = start_gateway(@svc, shim)
        delete :unbind, :binding_token => @bdg.binding_token.uuid
        response.status.should == 200
        binding = ServiceBinding.find_by_user_id_and_app_id(@user.id, @app.id)
        binding.should be_nil
        stop_gateway(gw_pid)
      end
    end


    describe '#unprovision' do
      before :each do
        cfg = ServiceConfig.new(:name => 'foo', :alias => 'bar', :service => @svc, :user => @user)
        cfg.save
        cfg.should be_valid
        @cfg = cfg

        bdg = ServiceBinding.new(
          :app   => @app,
          :user  => @user,
          :name  => 'xxx',
          :service_config => @cfg,
          :credentials => {},
          :binding_options => []
        )
        bdg.save
        bdg.should be_valid
        @bdg = bdg
      end

      it 'should return not authorized for unknown users' do
        request.env['HTTP_AUTHORIZATION'] = UserToken.create('bar@foo.com').encode
        delete :unprovision, :id => 'xxx'
        response.status.should == 403
      end

      it 'should return not found for unknown ids' do
        delete :unprovision, :id => 'xxx'
        response.status.should == 404
      end

      it 'should successfully delete known service configs and their associated bindings' do
        shim = ServiceProvisionerStub.new
        shim.stubs(:unprovision_service).returns(true)
        gw_pid = start_gateway(@svc, shim)
        delete :unprovision, :id => @cfg.name
        response.status.should == 200
        binding = ServiceBinding.find_by_user_id_and_app_id(@user.id, @app.id)
        binding.should be_nil
        cfg = ServiceConfig.find_by_id(@cfg.id)
        cfg.should be_nil
        stop_gateway(gw_pid)
      end
    end

    describe "#lifecycle_extension" do
      it 'should return not implemented error when lifecycle is disabled' do
        begin
          origin = AppConfig.delete :service_lifecycle
          %w(create_snapshot enum_snapshots serialized_url import_from_url import_from_data).each do |api|
            post api.to_sym, :id => 'xxx'
            response.status.should == 501
            resp = Yajl::Parser.parse(response.body)
            resp['description'].include?("not implemented").should == true
          end

          %w(snapshot_details rollback_snapshot).each do |api|
            post api.to_sym, :id => 'xxx', :sid => '1'
            response.status.should == 501
            resp = Yajl::Parser.parse(response.body)
            resp['description'].include?("not implemented").should == true
          end

          get :job_info, :id => 'xxx', :job_id => '1'
          response.status.should == 501
          resp = Yajl::Parser.parse(response.body)
          resp['description'].include?("not implemented").should == true
        ensure
          AppConfig[:service_lifecycle] = origin
        end
      end
    end

    describe "#create_snapshot" do

      it 'should return not authorized for unknown users' do
        request.env['HTTP_AUTHORIZATION'] = UserToken.create('bar@foo.com').encode
        post :create_snapshot, :id => 'xxx'
        response.status.should == 403
      end

      it 'should return not found for unknown ids' do
        post :create_snapshot, :id => 'xxx'
        response.status.should == 404
      end
    end

    describe "#enum_snapshots" do

      it 'should return not authorized for unknown users' do
        request.env['HTTP_AUTHORIZATION'] = UserToken.create('bar@foo.com').encode
        get :enum_snapshots, :id => 'xxx'
        response.status.should == 403
      end

      it 'should return not found for unknown ids' do
        get :enum_snapshots, :id => 'xxx'
        response.status.should == 404
      end
    end

    describe "#snapshot_details" do

      it 'should return not authorized for unknown users' do
        request.env['HTTP_AUTHORIZATION'] = UserToken.create('bar@foo.com').encode
        get :snapshot_details, :id => 'xxx' , :sid => 'yyy'
        response.status.should == 403
      end

      it 'should return not found for unknown ids' do
        get :snapshot_details, :id => 'xxx', :sid => 'yyy'
        response.status.should == 404
      end
    end

    describe "#rollback_snapshot" do

      it 'should return not authorized for unknown users' do
        request.env['HTTP_AUTHORIZATION'] = UserToken.create('bar@foo.com').encode
        put :rollback_snapshot, :id => 'xxx', :sid => 'yyy'
        response.status.should == 403
      end

      it 'should return not found for unknown ids' do
        put :snapshot_details, :id => 'xxx' , :sid => 'yyy'
        response.status.should == 404
      end
    end

    describe "#serialized_url" do

      it 'should return not authorized for unknown users' do
        request.env['HTTP_AUTHORIZATION'] = UserToken.create('bar@foo.com').encode
        get :serialized_url, :id => 'xxx'
        response.status.should == 403
      end

      it 'should return not found for unknown ids' do
        get :serialized_url, :id => 'xxx'
        response.status.should == 404
      end
    end

    describe "#import_from_url" do

      it 'should return not authorized for unknown users' do
        request.env['HTTP_AUTHORIZATION'] = UserToken.create('bar@foo.com').encode
        put :import_from_url, :id => 'xxx'
        response.status.should == 403
      end

      it 'should return not found for unknown ids' do
        put_msg :import_from_url, :id => 'xxx' do
          VCAP::Services::Api::SerializedURL.new(:url  => 'http://api.vcap.me')
        end
        response.status.should == 404
      end

      it 'should return bad request for malformed request' do
        put_msg :import_from_url, :id => 'xxx' do
          # supply wrong request
          VCAP::Services::Api::SerializedData.new(:data => "raw_data")
        end
        response.status.should == 400
      end
    end

    describe "#import_from_data" do

      it 'should return not authorized for unknown users' do
        request.env['HTTP_AUTHORIZATION'] = UserToken.create('bar@foo.com').encode
        put :import_from_data, :id => 'xxx'
        response.status.should == 403
      end

      it 'should return not found for unknown ids' do
        put_msg :import_from_data, :id => 'xxx' do
          VCAP::Services::Api::SerializedData.new(:data  => 'raw_data')
        end
        response.status.should == 404
      end
    end

    describe "#job_info" do

      it 'should return not authorized for unknown users' do
        request.env['HTTP_AUTHORIZATION'] = UserToken.create('bar@foo.com').encode
        get :job_info, :id => 'xxx', :job_id => 'yyy'
        response.status.should == 403
      end

      it 'should return not found for unknown ids' do
        get :job_info, :id => 'xxx' , :job_id => 'yyy'
        response.status.should == 404
      end
    end
  end

  def start_gateway(svc, shim)
    svc_info = {
      :name    => svc.name,
      :version => svc.version
    }
    uri = URI.parse(svc.url)
    gateway = VCAP::Services::SynchronousServiceGateway.new(:service => svc_info, :token => svc.token, :provisioner => shim)
    pid = Process.fork do
      # Prevent the subscriptions registered with the rails initializers from running when we fork the server and start it.
      # If we don't do this we run the risk of a) starting NATS if it isn't running, or b) sending messages
      # through an existing NATS server, possibly upsetting already running tests.
      EM.instance_variable_set(:@next_tick_queue, [])

      outfile = File.new('/dev/null', 'w+')
      $stderr.reopen(outfile)
      $stdout.reopen(outfile)
      trap("INT") { exit }
      Thin::Server.start(uri.host, uri.port, gateway, :signals => false)
    end
    server_alive = wait_for {port_open? uri.port}
    server_alive.should be_true

    # In case an exception is thrown before we can cleanup
    at_exit { Process.kill(9, pid) if VCAP.process_running?(pid) }

    pid
  end

  def stop_gateway(pid)
    Process.kill("INT", pid)
    Process.waitpid(pid)
  end

  def post_msg(*args, &blk)
    msg = yield
    request.env['RAW_POST_DATA'] = msg.encode
    post(*args)
  end

  def put_msg(*args, &blk)
    msg = yield
    request.env['RAW_POST_DATA'] = msg.encode
    put(*args)
  end

  def delete_msg(*args, &blk)
    msg = yield
    request.env['RAW_POST_DATA'] = msg.encode
    delete(*args)
  end

  def port_open?(port)
    port_open = true
    begin
      s = TCPSocket.new('localhost', port)
      s.close()
    rescue
      port_open = false
    end
    port_open
  end

  def wait_for(timeout=5, &predicate)
    start = Time.now()
    cond_met = predicate.call()
    while !cond_met && ((Time.new() - start) < timeout)
      cond_met = predicate.call()
      sleep(0.2)
    end
    cond_met
  end

end
