# frozen_string_literal: true

require "fastlane/plugin/fastlane_configurator/version"

module Fastlane
  module FastlaneConfigurator
    def self.all_classes
      Dir[File.expand_path("**/{actions,helper}/*.rb", File.dirname(__FILE__))]
    end
  end
end

Fastlane::FastlaneConfigurator.all_classes.each do |current|
  require current
end
