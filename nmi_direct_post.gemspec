# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'nmi_direct_post/version'

Gem::Specification.new do |spec|
  spec.name          = "nmi_direct_post"
  spec.version       = NmiDirectPost::VERSION
  spec.authors       = ["Isaac Betesh"]
  spec.email         = ["iybetesh@gmail.com"]
  spec.description   = %q{Gem that encapsulates the NMI Direct Post API in an ActiveRecord-like syntax}
  spec.summary       = `cat README.md`
  spec.homepage      = "https://github.com/betesh/nmi_direct_post"
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", ">= 1.3"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rspec"
  spec.add_development_dependency "rspec-rails"
  spec.add_development_dependency "simplecov"

  spec.add_dependency 'addressable'
  spec.add_dependency 'activemodel'
  spec.add_dependency 'activesupport', ' >= 3.0'
end
