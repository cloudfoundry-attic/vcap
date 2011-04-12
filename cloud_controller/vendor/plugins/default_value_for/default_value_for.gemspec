Gem::Specification.new do |s|
  s.name = %q{default_value_for}
  s.version = "1.0.1"
  s.summary = %q{Provides a way to specify default values for ActiveRecord models}
  s.description = %q{The default_value_for plugin allows one to define default values for ActiveRecord models in a declarative manner}
  s.email = %q{info@phusion.nl}
  s.homepage = %q{http://github.com/FooBarWidget/default_value_for}
  s.authors = ["Hongli Lai"]
  s.files = ['default_value_for.gemspec',
    'LICENSE.TXT', 'Rakefile', 'README.rdoc', 'test.rb',
    'init.rb',
    'lib/default_value_for.rb',
    'lib/default_value_for/railtie.rb',
    'lib/rails.rb'
  ]
end
