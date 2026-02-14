# -*- encoding: utf-8 -*-
# stub: puma_worker_killer 1.0.0 ruby lib

Gem::Specification.new do |s|
  s.name = "puma_worker_killer".freeze
  s.version = "1.0.0".freeze

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["Richard Schneeman".freeze]
  s.date = "2024-07-22"
  s.description = " Kills pumas, the code kind ".freeze
  s.email = ["richard.schneeman+rubygems@gmail.com".freeze]
  s.homepage = "https://github.com/schneems/puma_worker_killer".freeze
  s.licenses = ["MIT".freeze]
  s.rubygems_version = "3.5.9".freeze
  s.summary = "If you have a memory leak in your web code puma_worker_killer can keep it in check.".freeze

  s.installed_by_version = "3.6.9".freeze

  s.specification_version = 4

  s.add_runtime_dependency(%q<puma>.freeze, [">= 2.7".freeze])
  s.add_runtime_dependency(%q<bigdecimal>.freeze, [">= 2.0".freeze])
  s.add_runtime_dependency(%q<get_process_mem>.freeze, [">= 0.2".freeze])
  s.add_development_dependency(%q<rack>.freeze, [">= 3.0".freeze])
  s.add_development_dependency(%q<rake>.freeze, [">= 13.0".freeze])
  s.add_development_dependency(%q<rackup>.freeze, [">= 2.1".freeze])
  s.add_development_dependency(%q<test-unit>.freeze, [">= 0".freeze])
  s.add_development_dependency(%q<wait_for_it>.freeze, [">= 0.1".freeze])
end
