provides :cf_remote_file

require 'pathname'

default_action :create

attribute :checksum, :regex => /^[\da-fA-F]{64}$/, :required => true
attribute :id, :regex => /^.{133}$/, :required => true
attribute :owner, :kind_of => [Integer, String]
attribute :group, :kind_of => [Integer, String]
attribute :mode, :regex => /^0?\d{3,4}$/

attr_reader :path

def initialize(name, *reset)
  super
  @path = Pathname.new(name).expand_path
  @blob_host = {
    :url => "https://blob.cfblob.com",
    :uid => "bb6a0c89ef4048a8a0f814e25385d1c5/user1"
  }
end
