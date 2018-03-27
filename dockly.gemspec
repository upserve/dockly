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
  gem.add_dependency 'docker-api', '>= 1.14.0'
  gem.add_dependency 'dockly-util', '>= 0.0.9', '< 1.0'
  gem.add_dependency 'excon'
  gem.add_dependency 'aws-sdk', '~> 2.0'
  gem.add_dependency 'foreman'
  gem.add_dependency 'fpm', '~> 1.2.0'
  gem.add_dependency 'minigit', '~> 0.0.4'
  gem.add_development_dependency 'cane'
  gem.add_development_dependency 'pry'
  gem.add_development_dependency 'rake', '< 11.0'
  gem.add_development_dependency 'rspec', '~> 2.14.1'
  gem.add_development_dependency 'vcr'
  gem.add_development_dependency 'webmock', '<= 1.18.0'
  gem.add_development_dependency 'addressable', '<= 2.3.6'
end
