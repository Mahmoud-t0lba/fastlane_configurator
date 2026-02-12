# frozen_string_literal: true

lib = File.expand_path("lib", __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

require "fastlane/plugin/fastlane_configurator/version"

Gem::Specification.new do |spec|
  spec.name          = "fastlane-plugin-fastlane_configurator"
  spec.version       = Fastlane::FastlaneConfigurator::VERSION
  spec.author        = "tolba"
  spec.email         = "maintainers@example.com"

  spec.summary       = "Install and manage Fastlane configuration for Flutter projects"
  spec.homepage      = "https://github.com/tolba/fastlane-plugin-fastlane_configurator"
  spec.license       = "MIT"

  spec.files         = Dir["lib/**/*", "*.gemspec", "README.md", "LICENSE", "Gemfile"]
  spec.require_paths = ["lib"]

  spec.add_dependency("fastlane", ">= 2.220.0")
end
