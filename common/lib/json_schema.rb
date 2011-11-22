# Copyright (c) 2009-2011 VMware, Inc.
# This class provides dead simple declarative validation for decoded json using
# a fairly intuitive DSL like syntax.
#
# For example, the following is a sample schema that exercises all functionality
#
# {'foo' => [String],            # 'foo' must be a list of strings
#  'bar' => {'baz' => Fixnum,    # 'bar' must be a hash where
#            'jaz' => /foo/,     #   'baz' is a Fixnum, and
#           }                    #   'jaz' matches the regex /foo/
# }
#
class JsonSchema
  WILDCARD = Object

  # TODO(mjp): validate that schema is syntatically correct

  def initialize(schema)
    @schema = schema
  end

  def validate(json)
    _validate(json, @schema)
  end

  protected

  def _validate(json, schema)
    case schema
    when Class
      # Terminal case, type check
      klass = json.class
      if json.is_a? schema
        nil
      else
        "Type mismatch (expected #{schema}, got #{klass})"
      end

    when Hash
      # Recursive case, check for required params, recursively check them against the supplied schema
      missing_keys = schema.keys.select {|k| !json.has_key?(k)} if json.is_a? Hash

      if !(json.is_a? Hash)
        "Type mismatch (expected hash, got #{json.class})"
      elsif missing_keys.length > 0
        "Missing params: '#{missing_keys.join(', ')}'"
      else
        errs = nil
        schema.each_key do |k|
          sub_errs = _validate(json[k], schema[k])
          if sub_errs
            errs ||= {}
            errs[k] = sub_errs
          end
        end
        errs
      end

    when Array
      # Recursive case, check that array isn't empty, recursively check array against supplied schema
      if !(json.is_a? Array)
        "Type mismatch (expected array, got #{json.class}"
      else
        errs = nil
        json.each do |v|
          errs = _validate(v, schema[0])
          break if errs
        end
        errs
      end

    when Regexp
      if schema.match(json)
        nil
      else
        "Invalid value (doesn't match '#{schema.source})"
      end

    else
      # Terminal case, value check
      "Value mismatch (expected '#{schema}', got #{json})" unless json == schema
    end
  end
end
