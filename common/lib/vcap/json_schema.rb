# Copyright (c) 2009-2011 VMware, Inc.

# This provides very basic support for creating declarative validators
# for decoded json. Useful for validating things like configs or
# messages that are published via NATS.
#
# Basic usage:
#
# schema = VCAP::JsonSchema.build do
#   { :foo => [String],
#     :bar => {:baz => Integer},
#     optional(:jaz) => Float,
#   }
# end
#
# Fails:
#
# schema.validate({
#   'foo' => ['bar', 5],
#   'bar' => {'baz' => 7},
# })
#
# Succeeds:
#
# schema.validate({
#   'foo' => ['bar', 'baz'],
#   'bar' => {'baz' => 7},
# })
#
#
module VCAP
  module JsonSchema

    class SyntaxError < StandardError; end
    class ValidationError < StandardError
      attr_accessor :message
      def initialize(msg)
        @message = msg
      end

      def to_s
        @message
      end
    end

    class ValueError      < ValidationError; end
    class TypeError       < ValidationError; end
    class MissingKeyError < ValidationError; end

    # Defines an interface that all schemas must implement
    class BaseSchema
      # Verfies that val conforms to the schema being validated
      # Throws exceptions derived from ValidationError upon schema violations
      #
      # @param  Object val  An object decoded from json
      #
      # @return nil
      def validate(dec_json)
        raise NotImplementedError.new("You must implement validate")
      end
   end

    class BoolSchema < BaseSchema
      def validate(dec_json)
        unless dec_json.kind_of?(TrueClass) || dec_json.kind_of?(FalseClass)
          raise TypeError, "Expected instance of TrueClass or FalseClass, got #{dec_json.class}"
        end
      end
    end

    # Checks that supplied value is an instance of a given class
    class TypeSchema < BaseSchema
      def initialize(klass)
        raise ArgumentError, "You must supply a class #{klass} given" unless klass.kind_of?(Class)
        @klass = klass
      end

      def validate(dec_json)
        raise TypeError, "Expected instance of #{@klass}, got #{dec_json.class}" unless dec_json.kind_of?(@klass)
      end
    end

    # Checks that supplied value is an array, and each value in the array validates
    class ArraySchema < BaseSchema
      attr_accessor :item_schema

      def initialize(schema)
        raise ArgumentError, "You must supply a schema, #{schema.class} given" unless schema.kind_of?(BaseSchema)
        @item_schema = schema
      end

      def validate(dec_json)
        raise TypeError, "Expected instance of Array, #{dec_json.class} given" unless dec_json.kind_of?(Array)
        for v in dec_json
          @item_schema.validate(v)
        end
      end
    end

    # Check that required keys are present, and that they validate
    class HashSchema < BaseSchema
      class Field
        attr_reader :name, :schema
        attr_accessor :optional

        def initialize(name, schema, optional=false)
          raise ArgumentError, "Schema must be an instance of a schema, #{schema.class} given #{schema.inspect}" unless schema.kind_of?(BaseSchema)
          @name = name
          @schema = schema
          @optional = optional
        end
      end

      def initialize(kvs={})
        raise ArgumentError, "Expected Hash, #{kvs.class} given" unless kvs.is_a?(Hash)
        # Convert symbols to strings. Validation will be performed against decoded json, which will have
        # string keys.
        @fields = {}
        for k, v in kvs
          raise ArgumentError, "Expected schema for key #{k}, got #{v.class}" unless v.kind_of?(BaseSchema)
          k_s = k.to_s
          @fields[k_s] = Field.new(k_s, v, false)
        end
      end

      def required(name, schema)
        name_s = name.to_s
        @fields[name_s] = Field.new(name_s, schema, false)
      end

      def optional(name, schema)
        name_s = name.to_s
        @fields[name_s] = Field.new(name_s, schema, true)
      end

      def validate(dec_json)
        raise TypeError, "Expected instance of Hash, got instance of #{dec_json.class}" unless dec_json.kind_of?(Hash)

        missing_keys = []
        for k in @fields.keys
          missing_keys << k unless dec_json.has_key?(k) || @fields[k].optional
        end
        raise MissingKeyError, "Missing keys: #{missing_keys.join(', ')}" unless missing_keys.empty?

        for k, f in @fields
          next if f.optional && !dec_json.has_key?(k)
          begin
            f.schema.validate(dec_json[k])
          rescue ValidationError => ve
            ve.message = "'#{k}' => " + ve.message
            raise ve
          end
        end
      end
    end

    class << self
      class OptionalKeyMarker
        attr_reader :name
        def initialize(name)
          @name = name
        end

        def to_s
          @name.to_s
        end
      end

      def optional(key)
        OptionalKeyMarker.new(key)
      end

      def build(&blk)
        schema_def = instance_eval(&blk)
        parse(schema_def)
      end

      def parse(schema_def)
        case schema_def
        when VCAP::JsonSchema::BaseSchema
          schema_def
        when Hash
          schema = VCAP::JsonSchema::HashSchema.new
          for k, v in schema_def
            sym = k.kind_of?(OptionalKeyMarker) ? :optional : :required
            schema.send(sym, k, parse(v))
          end
          schema
        when Array
          raise SyntaxError, "Schema definition for an array must have exactly 1 element" unless schema_def.size == 1
          item_schema = parse(schema_def[0])
          VCAP::JsonSchema::ArraySchema.new(item_schema)
        when Class
          VCAP::JsonSchema::TypeSchema.new(schema_def)
        else
          raise SyntaxError, "Don't know what to do with class #{schema_def.class}"
        end
      end
    end

  end # VCAP::JsonSchema
end   # VCAP
