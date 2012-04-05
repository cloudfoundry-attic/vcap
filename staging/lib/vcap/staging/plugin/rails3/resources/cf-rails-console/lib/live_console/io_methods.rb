module LiveConsole::IOMethods
  List = []

  Dir[File.join(File.dirname(__FILE__), 'io_methods', '*')].each { |dir|
    entry = dir + '/' + File.basename(dir)
    fname = entry.sub /\.rb$/, ''
    classname = File.basename(entry,'.rb').capitalize.
    gsub(/_(\w)/) { $1.upcase }.sub(/io$/i, 'IO').to_sym
    mname = File.basename(fname).sub(/_io$/, '').to_sym

    autoload classname, fname
    List << mname

    define_method(mname) {
      const_get classname
    }
  }
  List.freeze

  extend self

  module IOMethod
    def initialize(opts)
      self.opts = self.class::DefaultOpts.merge opts
      unless missing_opts.empty?
        raise ArgumentError, "Missing opts for " \
          "#{self.class.name}:  #{missing_opts.inspect}"
      end
    end

    def missing_opts
      self.class::RequiredOpts - opts.keys
    end

    def self.included(other)
      other.instance_eval {
        readers = [:opts]
        attr_accessor *readers
        private *readers.map { |r| (r.to_s + '=').to_sym }
          other::RequiredOpts.each { |opt|
          define_method(opt) { opts[opt] }
        }
      }
    end
  end
end
