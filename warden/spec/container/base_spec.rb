require "warden/container/base"
require "spec_helper"

class SpecNetworkPool < Array
  alias :acquire :shift
  alias :release :push
end

describe Warden::Container::Base do

  # Shortcuts
  Container = Warden::Container::Base
  NetworkPool = SpecNetworkPool

  def new_connection
    connection = double("connection")
    connection.extend Warden::EventEmitter
    connection
  end

  let(:connection) do
    new_connection
  end

  let(:network) do
    Warden::Network::Address.new("127.0.0.0")
  end

  let(:network_pool) do
    NetworkPool.new
  end

  before(:all) do
    Warden::Logger.logger = nil
  end

  before(:each) do
    Container.reset!
    Container.network_pool = network_pool

    network_pool.push(network)
  end

  def initialize_container(connection = nil, options = {})
    container = Container.new(connection || new_connection, options)
    container.stub(:do_create)
    container.stub(:do_stop)
    container.stub(:do_destroy)
    container
  end

  context "initialization" do

    context "on success" do

      it "should acquire a network" do
        container = Container.new(connection)
        container.network.should == network
        network_pool.should be_empty
      end

      it "should register with the specified connection" do
        connection.should_receive(:on).with(:close)
        container = Container.new(connection)
        container.connections.should include(connection)
      end
    end

    context "on failure" do

      before(:each) do
        # Make initialization fail by raising from #register_connection
        connection.should_receive(:on).with(:close).and_raise(Warden::WardenError.new("failure"))
      end

      it "should release the acquired network" do
        expect do
          Container.new(connection)
        end.to raise_error

        network_pool.size.should == 1
      end
    end
  end

  context "create" do

    before(:each) do
      @container = initialize_container
    end

    it "should call #do_create" do
      @container.should_receive(:do_create)
      @container.create
    end

    it "should return the container handle" do
      @container.create.should == network.to_hex
    end

    it "should register with the global registry" do
      @container.create

      Container.registry.size.should == 1
    end

    context "on failure" do

      before(:each) do
        @container.stub(:do_create).and_raise(Warden::WardenError.new("create"))
      end

      it "should destroy" do
        @container.should_receive(:do_destroy)

        expect do
          @container.create
        end.to raise_error(/create/i)
      end

      it "should not register with the global registry" do
        expect do
          @container.create
        end.to raise_error

        Container.registry.should be_empty
      end

      it "should release the acquired network" do
        expect do
          @container.create
        end.to raise_error

        network_pool.size.should == 1
      end

      context "on failure of destroy" do

        before(:each) do
          @container.stub(:do_destroy).and_raise(Warden::WardenError.new("destroy"))
        end

        it "should raise original error" do
          expect do
            @container.create
          end.to raise_error(/create/i)
        end

        it "should not release the acquired network" do
          expect do
            @container.create
          end.to raise_error

          network_pool.should be_empty
        end
      end
    end
  end

  describe "stop" do

    before(:each) do
      @container = initialize_container
      @container.create
    end

    it "should call #do_stop" do
      @container.should_receive(:do_stop)
      @container.stop
    end

    it "should return ok" do
      @container.stop.should == "ok"
    end
  end

  describe "destroy" do

    before(:each) do
      @container = initialize_container
      @container.create
    end

    it "should call #do_destroy" do
      @container.should_receive(:do_destroy)
      @container.destroy
    end

    it "should return ok" do
      @container.destroy.should == "ok"
    end

    context "when stopped" do

      before(:each) do
        @container.stop
      end

      it "should not call #do_stop" do
        @container.should_not_receive(:do_stop)
        @container.destroy
      end
    end

    context "when not yet stopped" do

      it "should call #do_stop" do
        @container.should_receive(:do_stop)
        @container.destroy
      end

      it "should not care if #do_stop succeeds" do
        @container.should_receive(:do_stop).and_raise(Warden::WardenError.new("failure"))

        expect do
          @container.destroy
        end.to_not raise_error(/failure/i)
      end
    end
  end

  describe "connection management" do

    before(:each) do
      @connection = new_connection
      @container = initialize_container(@connection)
    end

    it "should not store existing connections more than once" do
      expect do
        @container.register_connection(@connection)
      end.to_not change(@container.connections, :size)
    end

    it "should store new connections" do
      another_connection = new_connection

      expect do
        @container.register_connection(another_connection)
      end.to change(@container.connections, :size)
    end

    it "should setup grace timer when the last connection closed" do
      @container.should_receive(:setup_grace_timer)
      @container.connections.size.should == 1
      @connection.emit(:close)
    end

    it "should setup grace timer when the next to last connection is closed" do
      @container.register_connection(new_connection)
      @container.should_not_receive(:setup_grace_timer)
      @container.connections.size.should == 2
      @connection.emit(:close)
    end
  end

  context "grace timer" do

    before(:each) do
      @container = initialize_container(new_connection, :grace_time => 0.02)
    end

    it "should fire after grace time" do
      em do
        @container.should_receive(:fire_grace_timer)
        @container.setup_grace_timer

        ::EM.add_timer(0.03) { done }
      end
    end

    it "should not fire when timer is cancelled" do
      em do
        @container.should_not_receive(:fire_grace_timer)
        @container.setup_grace_timer

        ::EM.add_timer(0.01) { @container.cancel_grace_timer }
        ::EM.add_timer(0.03) { done }
      end
    end

    context "when fired" do

      it "should destroy container" do
        em do
          @container.should_receive(:destroy)
          @container.setup_grace_timer

          ::EM.add_timer(0.03) { done }
        end
      end

      it "should ignore any WardenError raised by destroy" do
        em do
          @container.should_receive(:destroy).and_raise(Warden::WardenError.new("failure"))
          @container.setup_grace_timer

          ::EM.add_timer(0.03) { done }
        end
      end
    end
  end

  describe "state" do

    before(:each) do
      @container = initialize_container
    end

    shared_examples "succeeds when born" do |blk|

      it "succeeds when container was not yet created" do
        expect do
          blk.call(@container)
        end.to_not raise_error
      end

      it "fails when container was already created" do
        @container.create

        expect do
          blk.call(@container)
        end.to raise_error(/container state/i)
      end

      it "fails when container was already stopped" do
        @container.create
        @container.stop

        expect do
          blk.call(@container)
        end.to raise_error(/container state/i)
      end

      it "fails when container was already destroyed" do
        @container.create
        @container.destroy

        expect do
          blk.call(@container)
        end.to raise_error(/container state/i)
      end
    end

    shared_examples "succeeds when active" do |blk|

      it "succeeds when container was created" do
        @container.create

        expect do
          blk.call(@container)
        end.to_not raise_error
      end

      it "fails when container was not yet created" do
        expect do
          blk.call(@container)
        end.to raise_error(/container state/i)
      end

      it "fails when container was already stopped" do
        @container.create
        @container.stop

        expect do
          blk.call(@container)
        end.to raise_error(/container state/i)
      end

      it "fails when container was already destroyed" do
        @container.create
        @container.destroy

        expect do
          blk.call(@container)
        end.to raise_error(/container state/i)
      end
    end

    shared_examples "succeeds when active or stopped" do |blk|

      it "succeeds when container was created" do
        @container.create

        expect do
          blk.call(@container)
        end.to_not raise_error
      end

      it "succeeds when container was created and stopped" do
        @container.create
        @container.stop

        expect do
          blk.call(@container)
        end.to_not raise_error
      end

      it "fails when container was not yet created" do
        expect do
          blk.call(@container)
        end.to raise_error(/container state/i)
      end

      it "fails when container was already destroyed" do
        @container.create
        @container.stop
        @container.destroy

        expect do
          blk.call(@container)
        end.to raise_error(/container state/i)
      end
    end

    describe "create" do

      include_examples "succeeds when born", lambda { |container|
        container.create
      }
    end

    describe "stop" do

      include_examples "succeeds when active", lambda { |container|
        container.stop
      }
    end

    describe "destroy" do

      include_examples "succeeds when active or stopped", lambda { |container|
        container.destroy
      }
    end

    describe "spawn" do

      before(:each) do
        @job = double("job", :job_id => 1)
        @container.stub(:create_job).and_return(@job)
      end

      include_examples "succeeds when active", lambda { |container|
        container.spawn("echo foo")
      }
    end

    describe "net_in" do

      before(:each) do
        @container.stub(:do_net_in)
      end

      include_examples "succeeds when active", lambda { |container|
        container.net_in
      }
    end

    describe "net_out" do

      before(:each) do
        @container.stub(:do_net_out)
      end

      include_examples "succeeds when active", lambda { |container|
        container.net_out("something")
      }
    end

    describe "get_limit" do

      before(:each) do
        @container.stub(:get_limit_foo)
      end

      include_examples "succeeds when active or stopped", lambda { |container|
        container.get_limit(:foo)
      }
    end

    describe "set_limit" do

      before(:each) do
        @container.stub(:set_limit_foo)
      end

      include_examples "succeeds when active", lambda { |container|
        container.set_limit(:foo, "something")
      }
    end

    describe "copy in" do
      before(:each) do
        @container.stub(:do_copy_in)
      end

      include_examples "succeeds when active", lambda { |container|
        container.copy("in", "/tmp/foo", "/tmp/bar")
      }
    end

    describe "copy out" do
      before(:each) do
        @container.stub(:do_copy_out)
      end

      include_examples "succeeds when active", lambda { |container|
        container.copy("out", "/tmp/foo", "/tmp/bar")
      }
    end
  end
end
