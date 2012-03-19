spec = Gem::Specification.new do |s|
  s.name = 'vcap_common'
  s.version = '1.0.10'
  s.date = '2011-02-09'
  s.summary = 'vcap common'
  s.homepage = "http://github.com/vmware-ac/core"
  s.description = 'common vcap classes/methods'

  s.authors = ["Derek Collison"]
  s.email = ["derek.collison@gmail.com"]

  s.add_dependency('eventmachine', '~> 0.12.11.cloudfoundry.3')
  s.add_dependency('thin', '~> 1.3.1')
  s.add_dependency('yajl-ruby', '~> 0.8.3')
  s.add_dependency('nats', '~> 0.4.22.beta.8')
  s.add_dependency('posix-spawn', '~> 0.3.6')
  s.add_development_dependency('rake', '~> 0.9.2')

  s.require_paths = ['lib']

  s.files = Dir["lib/**/*.rb"]
end
