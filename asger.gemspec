# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'asger/version'

Gem::Specification.new do |spec|
  spec.name          = "asger"
  spec.version       = Asger::VERSION
  spec.authors       = ["Ed Ropple"]
  spec.email         = ["ed@edropple.com"]
  spec.summary       = %q{A persistent daemon that watches an AWS autoscaling group for changes and dispatches your code.}
  spec.homepage      = ""
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler",          "~> 1.7"
  spec.add_development_dependency "rake",             "~> 10.0"
  spec.add_development_dependency "pry"

  spec.add_runtime_dependency     'aws-sdk',          '~> 2.2.22'
  spec.add_runtime_dependency     'trollop',          '~> 2.1.1'
  spec.add_runtime_dependency     "hashie",             "~> 3.3"
  spec.add_runtime_dependency     'activesupport',      '~> 4.2.0'
end
