# -*- encoding: utf-8 -*-
require File.expand_path('../lib/dockly/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["Swipely, Inc."]
  gem.email         = %w{tomhulihan@swipely.com bright@swipely.com toddlunter@swipely.com}
  gem.description   = %q{Packaging made easy}
  gem.summary       = %q{Packaging made easy}
  gem.homepage      = "https://github.com/swipely/dockly"
  gem.files         = `git ls-files`.split($\)
  gem.license       = 'MIT'
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.name          = "dockly"
  gem.require_paths = %w{lib}
  gem.version       = Dockly::VERSION
  gem.add_dependency 'clamp', '~> 0.6'
  gem.add_dependency 'docker-api', '~> 1.8.0'
  gem.add_dependency 'dockly-util', '~> 0.0.7'
  gem.add_dependency 'excon'
  gem.add_dependency 'fog', '~> 1.18.0'
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
