# Copyright (c) 2009-2011 VMware, Inc.
require 'spec_helper'

describe VCAP::JsonSchema::BoolSchema do
  describe '#validate' do
    before :all do
      @schema = VCAP::JsonSchema::BoolSchema.new
    end

    it 'should not raise an error when supplied instances of TrueClass' do
      expect { @schema.validate(true) }.to_not raise_error
    end

    it 'should not raise an error when supplied instances of FalseClass' do
      expect { @schema.validate(false) }.to_not raise_error
    end

    it 'should raise an error when supplied instances not of TrueClass or FalseClass' do
      expect { @schema.validate('zazzle') }.to raise_error(VCAP::JsonSchema::TypeError)
    end
  end
end

describe VCAP::JsonSchema::TypeSchema do
  describe '#initialize' do
    it 'should raise an exception if supplied with non class instance' do
      expect { VCAP::JsonSchema::TypeSchema.new('foo') }.to raise_error(ArgumentError)
    end

    it 'should not raise an exception if not supplied with a class instance' do
      expect { VCAP::JsonSchema::TypeSchema.new(String) }.to_not raise_error
    end
  end

  describe '#validate' do
    before :all do
      @schema = VCAP::JsonSchema::TypeSchema.new(String)
    end

    it "should not raise exceptions for configured type" do
      expect { @schema.validate('foo') }.to_not raise_error
    end

    it "should raise exceptions on type mistmatch" do
      expect { @schema.validate(1.5) }.to raise_error(VCAP::JsonSchema::TypeError)
    end
  end
end

describe VCAP::JsonSchema::ArraySchema do
  before :all do
    @item_schema = VCAP::JsonSchema::TypeSchema.new(String)
    @schema = VCAP::JsonSchema::ArraySchema.new(@item_schema)
  end

  describe '#initialize' do
    it 'should raise an exception if supplied with a non-schema instance' do
      expect { VCAP::JsonSchema::ArraySchema.new('foo') }.to raise_error(ArgumentError)
    end

    it 'should not raise exceptions if supplied with a schema instance' do
      expect { VCAP::JsonSchema::ArraySchema.new(@item_schema) }.to_not raise_error
    end
  end

  describe '#validate' do
    it 'should raise an exception if asked to validate a non-array type' do
      expect { @schema.validate('foo') }.to raise_error(VCAP::JsonSchema::TypeError)
    end

    it 'should raise an exception if items do not validate against the item schema' do
      expect { @schema.validate(['a', 'b', 5.5]) }.to raise_error(VCAP::JsonSchema::TypeError)
    end

    it 'should not raise an exception if all items validate against the item schema' do
      expect { @schema.validate(['a', 'b', 'c']) }.to_not raise_error
    end
  end
end

describe VCAP::JsonSchema::HashSchema do
  before :all do
    @item_schema = VCAP::JsonSchema::TypeSchema.new(String)
    @array_schema = VCAP::JsonSchema::ArraySchema.new(@item_schema)
    @schema = VCAP::JsonSchema::HashSchema.new
    @schema.required('foo', @array_schema)
    @schema.optional(:bar, @item_schema)
  end

  describe '#initialize' do
    it 'should raise an exception if supplied with a non-hash instance' do
      expect { VCAP::JsonSchema::HashSchema.new('foo') }.to raise_error(ArgumentError)
    end

    it 'should raise an exception if supplied keys do not map to schema instances' do
      expect { VCAP::JsonSchema::HashSchema.new({'foo' => 'bar'}) }.to raise_error(ArgumentError)
    end
  end

  describe '#validate' do
    it 'should raise an exception if asked to validate a non-hash type' do
      expect { @schema.validate('foo') }.to raise_error(VCAP::JsonSchema::TypeError)
    end

    it 'should raise an exception if some keys are missing' do
      expect { @schema.validate({'bar' => 'baz'}) }.to raise_error(VCAP::JsonSchema::MissingKeyError)
    end

    it 'should raise an exception if items do not validate against the item schema' do
      expect { @schema.validate({'foo' => 'baz'}) }.to raise_error(VCAP::JsonSchema::TypeError)
    end

    it 'should raise an exception if optional keys are present and violate their schemas' do
      expect { @schema.validate({'foo' => ['bar'], 'bar' => 1}) }.to raise_error(VCAP::JsonSchema::TypeError)
    end

    it 'should not raise an exception if items validate and optional keys are not present' do
      expect { @schema.validate({'foo' => ['bar']}) }.to_not raise_error
    end
  end
end

describe VCAP::JsonSchema do
  describe '.parse' do
    it 'should raise exceptions for malformed arrays' do
      expect { VCAP::JsonSchema.parse([]) }.to raise_error(VCAP::JsonSchema::SyntaxError)
    end

    it 'should raise exceptions for types that do not have an associated schema' do
      expect { VCAP::JsonSchema.parse(['foo']) }.to raise_error(VCAP::JsonSchema::SyntaxError)
    end
  end

  describe '.build' do
    it 'should build schemas' do
      schema = VCAP::JsonSchema.build do
        String
      end
      schema.class.should == VCAP::JsonSchema::TypeSchema

      schema = VCAP::JsonSchema.build do
        { :foo => String,
          optional(:bar) => Integer,
        }
      end
      schema.class.should == VCAP::JsonSchema::HashSchema
      expect { schema.validate({'foo' => 'bar', 'bar' => 5.5}) }.to raise_error(VCAP::JsonSchema::TypeError)
      schema = VCAP::JsonSchema.build do
        { :foo => String,
          :bar => {
            :baz => [{:jaz => Integer}]
          }
        }
      end
      expect { schema.validate({'foo' => 'x', 'bar' => { 'baz' => [{'jaz' => 5.5}]}}) }.to raise_error(VCAP::JsonSchema::TypeError)
      expect { schema.validate({'foo' => 'x', 'bar' => { 'baz' => [{'jaz' => 5}]}}) }.to_not raise_error
    end
  end
end
