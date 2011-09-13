require 'spec_helper'

describe StagingPlugin::Config do
  describe '#from_file' do
    it 'should symbolize keys for service bindings' do
      tf = Tempfile.new('test_config')
      svc = {
        :label => 'hello',
        :tags  => ['tag1', 'tag2'],
        :name  => 'my_test_svc',
        :credentials => {
          :hostname => 'localhost',
          :port     => 12345,
          :password => 'sekret',
          :name     => 'test',
        },
        :options => {},
        :plan => 'free',
        :plan_option => 'zazzle',
      }

      config = {
        'source_dir'  => 'test',
        'dest_dir'    => 'test',
        'environment' => {
          'framework' => 'sinatra',
          'runtime'   => 'ruby',
          'resources' => {
            'memory'  => 128,
            'disk'    => 2048,
            'fds'     => 1024,
          },
          'services'  => [svc],
        }
      }

      StagingPlugin::Config.to_file(config, tf.path)
      parsed_cfg = StagingPlugin::Config.from_file(tf.path)
      parsed_cfg[:environment][:services][0].should == svc
    end
  end
end
