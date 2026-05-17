# frozen_string_literal: true

lib = File.expand_path("lib", __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require_relative "lib/roo/smarter_csv/version"

Gem::Specification.new do |spec|
  spec.name          = "roo-smarter_csv"
  spec.version       = Roo::SmarterCSV::VERSION
  spec.authors       = ["Tilo Sloboda"]
  spec.email         = ["tilo.slobodal@gmail.com"]
  spec.summary       = "High-performance CSV support for Roo using SmarterCSV"
  spec.description   = "Extends Roo with SmarterCSV integration for robust, fast CSV parsing"
  spec.homepage      = "https://github.com/tilo/roo-smarter_csv"
  spec.license       = "MIT"
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.require_paths = ["lib"]

  spec.required_ruby_version = ">= 2.6.0" # same as SmarterCSV

  # Dependencies
  spec.add_dependency "roo", ">= 2.0.0", "< 4"   # roo 4.x is not out yet
  spec.add_dependency "smarter_csv", ">= 1.15.0" # it is recommended to use the latest version

  # Development dependencies
  spec.add_development_dependency "bundler", ">= 1.7"
  spec.add_development_dependency "matrix"
  spec.add_development_dependency "minitest", ">= 5.19.0"
  spec.add_development_dependency "rake", ">= 10.0"
  spec.add_development_dependency "rspec", ">= 3.0"
end
