# Copyright (c) 2009-2011 VMware, Inc.
require 'rubygems'

require 'yajl'

require 'json_schema'

class JsonMessage
  # Base error class that all other JsonMessage related errors should inherit from
  class Error < StandardError
  end

  # Failed to parse json during +decode+
  class ParseError < Error
  end

  # One or more field's values didn't match their schema
  class ValidationError < Error
    def initialize(field_errs)
      @field_errs = field_errs
    end

    def to_s
      err_strs = @field_errs.map{|f, e| "Field: #{f}, Error: #{e}"}
      err_strs.join(', ')
    end
  end

  class Field
    attr_reader :name, :schema, :required

    def initialize(name, schema, required=true)
      @name = name
      @schema = schema.is_a?(JsonSchema) ? schema : JsonSchema.new(schema)
      @required = required
    end
  end

  class << self
    attr_reader :fields

    def schema(&blk)
      instance_eval &blk
    end

    def decode(json)
      begin
        dec_json = Yajl::Parser.parse(json)
      rescue => e
        raise ParseError, e.to_s
      end

      from_decoded_json(dec_json)
    end

    def from_decoded_json(dec_json)
      raise ParseError, "Decoded JSON cannot be nil" unless dec_json

      errs = {}

      # Treat null values as if the keys aren't present. This isn't as strict as one would like,
      # but conforms to typical use cases.
      dec_json.delete_if {|k, v| v == nil}

      # Collect errors by field
      @fields.each do |name, field|
        err = nil
        name_s = name.to_s
        if dec_json.has_key?(name_s)
          err = field.schema.validate(dec_json[name_s])
        elsif field.required
          err = "Missing field #{name}"
        end
        errs[name] = err if err
      end

      raise ValidationError.new(errs) unless errs.empty?

      new(dec_json)
    end

    def required(field_name, schema=JsonSchema::WILDCARD)
      define_field(field_name, schema, true)
    end

    def optional(field_name, schema=JsonSchema::WILDCARD)
      define_field(field_name, schema, false)
    end

    protected

    def define_field(name, schema, required)
      name = name.to_sym

      @fields ||= {}
      @fields[name] = Field.new(name, schema, required)

      define_method name.to_sym do
        @msg[name]
      end

      define_method "#{name}=".to_sym do |value|
        set_field(name, value)
      end
    end
  end

  def initialize(fields={})
    @msg = {}
    fields.each {|k, v| set_field(k, v)}
  end

  def encode
    if self.class.fields
      missing_fields = {}
      self.class.fields.each do |name, field|
        missing_fields[name] = "Missing field #{name}" unless (!field.required || @msg.has_key?(name))
      end
      raise ValidationError.new(missing_fields) unless missing_fields.empty?
    end

    Yajl::Encoder.encode(@msg)
  end

  def extract
    @msg.dup.freeze
  end

  protected

  def set_field(field, value)
    field = field.to_sym
    raise ValidationError.new({field => "Unknown field #{field}"}) unless self.class.fields.has_key?(field)

    errs = self.class.fields[field].schema.validate(value)
    raise ValidationError.new({field => errs}) if errs
    @msg[field] = value
  end
end
