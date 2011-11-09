require 'spec_helper'

describe AppPackage do
  before :all do
    EM.instance_variable_set(:@next_tick_queue, [])
  end

  describe '#unpack_upload' do
    it 'should raise an instance of AppPackageError if unzip exits with a nonzero status code' do
      invalid_zip = Tempfile.new('app_package_test')
      app_package = AppPackage.new(nil, invalid_zip)
      em do
        Fiber.new do
          expect do
            app_package.send(:unpack_upload)
          end.to raise_error(AppPackageError)
          EM.stop
        end.resume
      end
    end
  end

  describe '.blocking_defer' do
    it 'should result the result of the deferred operation' do
      deferred_result = nil
      em do
        Fiber.new do
          deferred_result = AppPackage.blocking_defer { 'hi' }
          EM.stop
        end.resume
      end
      deferred_result.should == 'hi'
    end

    it 'should propagate exceptions raised inside the deferred block out to the calling fiber' do
      deferred_result = nil
      em do
        Fiber.new do
          expect do
            deferred_result = AppPackage.blocking_defer { raise "HI" }
          end.to raise_error(RuntimeError)
          EM.stop
        end.resume
      end
    end
  end

  describe '.repack_app_in' do
    it 'should raise an instance of AppPackageError if zipping the application fails' do
      nonexistant_dir = Dir.mktmpdir
      FileUtils.rm_rf(nonexistant_dir)
      em do
        Fiber.new do
          expect do
            AppPackage.repack_app_in(nonexistant_dir, nonexistant_dir, :zip)
          end.to raise_error(AppPackageError)
          EM.stop
        end.resume
      end
    end
  end

  def em(timeout=5)
    EM.run do
      EM.add_timer(timeout) { EM.stop }
      yield
    end
  end
end
