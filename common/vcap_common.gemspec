spec = Gem::Specification.new do |s|
  s.name = 'vcap_common'
  s.version = 0.99
  s.date = '2011-02-09'
  s.summary = 'vcap common'
  s.homepage = "http://github.com/vmware-ac/core"
  s.description = 'common vcap classes/methods'

  s.authors = ["Derek Collison"]
  s.email = ["derek.collison@gmail.com"]

  s.add_dependency('eventmachine', '~> 0.12.10')
  s.add_dependency('thin')
  s.add_dependency('yajl-ruby')
  s.add_dependency('nats')
  s.add_dependency('logging', '>= 1.5.0')

  s.require_paths = ['lib']

  s.files = Dir["lib/**/*.rb"]
end
