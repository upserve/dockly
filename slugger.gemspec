# -*- encoding: utf-8 -*-
require File.expand_path('../lib/slugger/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["Swipely, Inc."]
  gem.email         = %w{tomhulihan@swipely.com bright@swipely.com toddlunter@swipely.com}
  gem.description   = %q{Packaging made easy}
  gem.summary       = %q{Packaging made easy}
  gem.homepage      = "https://github.com/swipely/slugger"

  gem.files         = `git ls-files`.split($\)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.name          = "slugger"
  gem.require_paths = %w{lib}
  gem.version       = Slugger::VERSION
  gem.add_dependency 'docker-api', '~> 1.5.2'
  gem.add_dependency 'dsl', '0.0.3'
  gem.add_dependency 'excon'
  gem.add_dependency 'fog', '~> 1.14.0'
  gem.add_dependency 'foreman'
  gem.add_dependency 'fpm', '~> 0.4.42'
  gem.add_dependency 'grit'
  gem.add_development_dependency 'cane'
  gem.add_development_dependency 'pry'
  gem.add_development_dependency 'rake'
  gem.add_development_dependency 'rspec'
  gem.add_development_dependency 'vcr'
  gem.add_development_dependency 'webmock'
end
