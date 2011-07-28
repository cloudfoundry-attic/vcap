# Copyright (c) 2009-2011 VMware, Inc.
require 'spec_helper'

describe VCAP::Config do
  describe '.define_schema' do
    it 'should build the corresponding json schema' do
      class MyConfig < VCAP::Config
        define_schema do
          [Integer]
        end
      end

      MyConfig.schema.should be_instance_of(VCAP::JsonSchema::ArraySchema)
      MyConfig.schema.item_schema.should be_instance_of(VCAP::JsonSchema::TypeSchema)
    end
  end

  describe '.from_file' do
    it 'should load and validate a config from a yaml file' do
      class TestConfig < VCAP::Config
        define_schema do
          { :name => String,
            :nums => [Integer],
            optional(:not_needed) => {
              :float => Float
            }
          }
        end
      end

      # Valid config
      exp_cfg = {
        :name => 'test_config',
        :nums => [1, 2, 3],
        :not_needed => {
          :float => 1.1,
        }
      }
      cfg = TestConfig.from_file(fixture_path('valid_config.yml'))
      cfg.should == exp_cfg

      # Invalid config
      expect { TestConfig.from_file(fixture_path('invalid_config.yml')) }.to raise_error(VCAP::JsonSchema::ValidationError)
    end
  end
end
