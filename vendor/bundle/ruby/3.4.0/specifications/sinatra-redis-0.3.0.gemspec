# -*- encoding: utf-8 -*-
# stub: sinatra-redis 0.3.0 ruby lib

Gem::Specification.new do |s|
  s.name = "sinatra-redis".freeze
  s.version = "0.3.0".freeze

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["Blake Mizerany".freeze]
  s.date = "2009-09-21"
  s.description = "Extends Sinatra with redis helpers for instant redis use".freeze
  s.email = "blake.mizerany@gmail.com".freeze
  s.extra_rdoc_files = ["README.md".freeze]
  s.files = ["README.md".freeze]
  s.homepage = "http://github.com/rtomayko/sinatra-redis".freeze
  s.rdoc_options = ["--line-numbers".freeze, "--inline-source".freeze, "--title".freeze, "Sinatra::Redis".freeze]
  s.rubygems_version = "1.3.6".freeze
  s.summary = "Extends Sinatra with redis helpers for instant redis use".freeze

  s.installed_by_version = "3.6.9".freeze

  s.specification_version = 2

  s.add_runtime_dependency(%q<redis>.freeze, [">= 0".freeze])
  s.add_runtime_dependency(%q<sinatra>.freeze, [">= 0.9.4".freeze])
end
