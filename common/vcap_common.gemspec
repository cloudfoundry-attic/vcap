spec = Gem::Specification.new do |s|
  s.name = 'vcap_common'
  s.version = '1.0.2'
  s.date = '2011-02-09'
  s.summary = 'vcap common'
  s.homepage = "http://github.com/vmware-ac/core"
  s.description = 'common vcap classes/methods'

  s.authors = ["Derek Collison"]
  s.email = ["derek.collison@gmail.com"]

  s.add_dependency('eventmachine')
  s.add_dependency('thin', '~> 1.2.11')
  s.add_dependency('yajl-ruby', '~> 0.8.3')
  s.add_dependency('nats', '~> 0.4.10')
  s.add_dependency('logging', '>= 1.5.0')
  s.add_dependency('posix-spawn', '~> 0.3.6')
  s.add_development_dependency('rake', '~> 0.9.2')

  s.require_paths = ['lib']

  s.files = Dir["lib/**/*.rb"]
end
