require 'uuidtools'

class BindingToken < ActiveRecord::Base
  belongs_to :service_config
  has_many :service_bindings, :dependent => :destroy

  validates_presence_of :uuid, :label
  validates_uniqueness_of :uuid

  serialize :binding_options

  class << self
    def generate(opts={})
      raise ArgumentError, "You cannot supply uuid" if opts.has_key? :uuid
      tok = new(opts)
      tok.uuid = UUIDTools::UUID.random_create.to_s
      tok
    end
  end

  protected

  def initialize(opts={})
    super(opts)
  end
end
