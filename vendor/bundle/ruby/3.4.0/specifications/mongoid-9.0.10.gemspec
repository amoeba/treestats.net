# -*- encoding: utf-8 -*-
# stub: mongoid 9.0.10 ruby lib

Gem::Specification.new do |s|
  s.name = "mongoid".freeze
  s.version = "9.0.10".freeze

  s.required_rubygems_version = Gem::Requirement.new(">= 1.3.6".freeze) if s.respond_to? :required_rubygems_version=
  s.metadata = { "bug_tracker_uri" => "https://jira.mongodb.org/projects/MONGOID", "changelog_uri" => "https://github.com/mongodb/mongoid/releases", "documentation_uri" => "https://www.mongodb.com/docs/mongoid/", "homepage_uri" => "https://mongoid.org/", "source_code_uri" => "https://github.com/mongodb/mongoid" } if s.respond_to? :metadata=
  s.require_paths = ["lib".freeze]
  s.authors = ["The MongoDB Ruby Team".freeze]
  s.date = "1980-01-02"
  s.description = "Mongoid is an ODM (Object Document Mapper) Framework for MongoDB, written in Ruby.".freeze
  s.email = "dbx-ruby@mongodb.com".freeze
  s.homepage = "https://mongoid.org".freeze
  s.licenses = ["MIT".freeze]
  s.required_ruby_version = Gem::Requirement.new(">= 2.7".freeze)
  s.rubygems_version = "4.0.4".freeze
  s.summary = "Elegant Persistence in Ruby for MongoDB.".freeze

  s.installed_by_version = "3.6.9".freeze

  s.specification_version = 4

  s.add_runtime_dependency(%q<activemodel>.freeze, [">= 5.1".freeze, "< 8.2".freeze, "!= 7.0.0".freeze])
  s.add_runtime_dependency(%q<mongo>.freeze, [">= 2.18.0".freeze, "< 3.0.0".freeze])
  s.add_runtime_dependency(%q<concurrent-ruby>.freeze, [">= 1.0.5".freeze, "< 2.0".freeze])
  s.add_development_dependency(%q<bson>.freeze, [">= 4.14.0".freeze, "< 6.0.0".freeze])
end
