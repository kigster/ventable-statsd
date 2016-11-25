# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'ventable/statsd/version'

Gem::Specification.new do |spec|
  spec.name          = 'ventable-statsd'
  spec.version       = Ventable::Statsd::VERSION
  spec.authors       = ['Konstantin Gredeskoul']
  spec.email         = ['kig@reinvent.one']

  spec.summary       = %q{Integrate Ventable with Statsd in order to track some or all events that occur using a light-weight UDP protocol.}
  spec.description   = %q{Integrate Ventable with Statsd in order to track some or all events that occur using a light-weight UDP protocol.}
  spec.homepage      = 'https://github.com/kigster/ventable-statsd'
  spec.license       = 'MIT'

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end

  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_dependency 'activesupport'
  spec.add_dependency 'ventable', '~> 1.0'

  spec.add_development_dependency 'yard'
  spec.add_development_dependency 'simplecov', '~> 0.12'
  spec.add_development_dependency 'codeclimate-test-reporter', '~> 1.0'

  spec.add_development_dependency 'bundler', '~> 1.13'
  spec.add_development_dependency 'rake', '~> 10.0'
  spec.add_development_dependency 'rspec', '~> 3.0'
end
