# frozen_string_literal: true

require "fileutils"

module Fastlane
  module Actions
    class ConfigureFastlaneAction < Action
      PLUGIN_GEM_NAME = "fastlane-plugin-fastlane_configurator"

      def self.run(params)
        project_root = File.expand_path(params[:project_root])
        fastlane_dir = File.join(project_root, "fastlane")
        workflow_dir = File.join(project_root, ".github", "workflows")

        overwrite = params[:overwrite]
        configure_env = params[:configure_env]
        configure_ci = params[:configure_ci]
        workflow_filename = normalized_value(params[:workflow_filename]) || "mobile_delivery.yml"
        ci_branch = normalized_value(params[:ci_branch]) || "main"

        FileUtils.mkdir_p(fastlane_dir)

        ios_bundle_id = normalized_value(params[:ios_bundle_id]) || infer_ios_bundle_id(project_root) || "com.example.app"
        android_package_name = normalized_value(params[:android_package_name]) || infer_android_package_name(project_root) || "com.example.app"

        UI.important("Using iOS bundle id: #{ios_bundle_id}")
        UI.important("Using Android package name: #{android_package_name}")

        results = {}
        results["fastlane/Fastfile"] = write_file(
          path: File.join(fastlane_dir, "Fastfile"),
          content: build_fastfile(android_package_name),
          overwrite: overwrite
        )
        results["fastlane/Appfile"] = write_file(
          path: File.join(fastlane_dir, "Appfile"),
          content: build_appfile(
            ios_bundle_id: ios_bundle_id,
            apple_id: normalized_value(params[:apple_id]),
            team_id: normalized_value(params[:team_id]),
            itc_team_id: normalized_value(params[:itc_team_id])
          ),
          overwrite: overwrite
        )

        results["fastlane/Pluginfile"] = ensure_pluginfile(File.join(fastlane_dir, "Pluginfile"))

        if configure_env
          results["fastlane/.env.default"] = write_file(
            path: File.join(fastlane_dir, ".env.default"),
            content: build_env_file(
              ios_bundle_id: ios_bundle_id,
              android_package_name: android_package_name,
              apple_id: normalized_value(params[:apple_id]),
              team_id: normalized_value(params[:team_id]),
              itc_team_id: normalized_value(params[:itc_team_id])
            ),
            overwrite: overwrite
          )
        end

        if configure_ci
          FileUtils.mkdir_p(workflow_dir)
          workflow_path = File.join(workflow_dir, workflow_filename)
          results[".github/workflows/#{workflow_filename}"] = write_file(
            path: workflow_path,
            content: build_github_workflow(ci_branch),
            overwrite: overwrite
          )
        end

        UI.success("Fastlane configuration completed: #{fastlane_dir}")
        results.each { |file, status| UI.message("- #{file}: #{status}") }

        results
      end

      def self.description
        "Install fastlane config with ready-to-run commands for Firebase and GitHub Actions"
      end

      def self.authors
        ["tolba"]
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(
            key: :project_root,
            env_name: "FL_CONFIGURE_FASTLANE_PROJECT_ROOT",
            description: "Root path of the Flutter project",
            default_value: Dir.pwd,
            verify_block: proc do |value|
              UI.user_error!("project_root does not exist: #{value}") unless Dir.exist?(value)
            end
          ),
          FastlaneCore::ConfigItem.new(
            key: :ios_bundle_id,
            env_name: "FL_CONFIGURE_FASTLANE_IOS_BUNDLE_ID",
            description: "iOS bundle id (defaults to inferred value from iOS project)",
            optional: true
          ),
          FastlaneCore::ConfigItem.new(
            key: :android_package_name,
            env_name: "FL_CONFIGURE_FASTLANE_ANDROID_PACKAGE_NAME",
            description: "Android package name (defaults to inferred value from Android project)",
            optional: true
          ),
          FastlaneCore::ConfigItem.new(
            key: :apple_id,
            env_name: "FL_CONFIGURE_FASTLANE_APPLE_ID",
            description: "Apple ID email used by fastlane",
            optional: true
          ),
          FastlaneCore::ConfigItem.new(
            key: :team_id,
            env_name: "FL_CONFIGURE_FASTLANE_TEAM_ID",
            description: "Apple Developer Team ID",
            optional: true
          ),
          FastlaneCore::ConfigItem.new(
            key: :itc_team_id,
            env_name: "FL_CONFIGURE_FASTLANE_ITC_TEAM_ID",
            description: "App Store Connect Team ID",
            optional: true
          ),
          FastlaneCore::ConfigItem.new(
            key: :configure_env,
            env_name: "FL_CONFIGURE_FASTLANE_CONFIGURE_ENV",
            description: "Create fastlane/.env.default with common variables",
            is_string: false,
            default_value: true
          ),
          FastlaneCore::ConfigItem.new(
            key: :configure_ci,
            env_name: "FL_CONFIGURE_FASTLANE_CONFIGURE_CI",
            description: "Create a GitHub Actions workflow wired to generated fastlane lanes",
            is_string: false,
            default_value: true
          ),
          FastlaneCore::ConfigItem.new(
            key: :workflow_filename,
            env_name: "FL_CONFIGURE_FASTLANE_WORKFLOW_FILENAME",
            description: "Workflow filename under .github/workflows",
            optional: true
          ),
          FastlaneCore::ConfigItem.new(
            key: :ci_branch,
            env_name: "FL_CONFIGURE_FASTLANE_CI_BRANCH",
            description: "Branch that triggers CI workflow push",
            default_value: "main"
          ),
          FastlaneCore::ConfigItem.new(
            key: :overwrite,
            env_name: "FL_CONFIGURE_FASTLANE_OVERWRITE",
            description: "Overwrite existing generated files",
            is_string: false,
            default_value: false
          )
        ]
      end

      def self.return_value
        "Hash of written files and their write status (created, updated, skipped, unchanged)"
      end

      def self.details
        "Creates fastlane files, ready commands, Firebase distribution lanes, and GitHub Actions workflow."
      end

      def self.example_code
        [
          "configure_fastlane",
          "configure_fastlane(overwrite: true)",
          "configure_fastlane(configure_ci: true, ci_branch: \"main\")"
        ]
      end

      def self.category
        :building
      end

      def self.is_supported?(_platform)
        true
      end

      def self.normalized_value(value)
        return nil if value.nil?

        stripped = value.to_s.strip
        stripped.empty? ? nil : stripped
      end

      def self.write_file(path:, content:, overwrite:)
        exists = File.exist?(path)
        return "skipped" if exists && !overwrite

        File.write(path, content)
        exists ? "updated" : "created"
      end

      def self.ensure_pluginfile(path)
        line = %(gem "#{PLUGIN_GEM_NAME}")

        unless File.exist?(path)
          File.write(path, "# Autogenerated by configure_fastlane action\n#{line}\n")
          return "created"
        end

        content = File.read(path)
        return "unchanged" if content.include?(line)

        updated_content = content.end_with?("\n") ? content : "#{content}\n"
        updated_content << "#{line}\n"
        File.write(path, updated_content)
        "updated"
      end

      def self.build_fastfile(android_package_name)
        <<~RUBY
          # Autogenerated by configure_fastlane action from fastlane-plugin-fastlane_configurator
          default_platform(:android)

          desc "Fetch app/build metadata and write JSON for CI"
          lane :fetch_data do |options|
            fetch_mobile_data(
              project_root: ".",
              output_path: options[:output_path] || "fastlane/build_data.json",
              include_github: true
            )
          end

          platform :android do
            desc "Build Android AAB release for Flutter"
            lane :build_android do
              sh("flutter", "pub", "get")
              sh("flutter", "build", "appbundle", "--release")
            end

            desc "Distribute Android build to Firebase App Distribution"
            lane :firebase_android do |options|
              artifact_path = options[:artifact_path] || Dir["build/app/outputs/bundle/release/*.aab"].max_by { |file| File.mtime(file) }
              UI.user_error!("Android artifact not found. Run build_android first.") unless artifact_path

              app_id = options[:app_id] || ENV["FIREBASE_APP_ID_ANDROID"]
              token = ENV["FIREBASE_TOKEN"]
              groups = options[:groups] || ENV["FIREBASE_TESTER_GROUPS"]
              release_notes = options[:release_notes] || ENV["FIREBASE_RELEASE_NOTES"]

              UI.user_error!("Missing FIREBASE_APP_ID_ANDROID") if app_id.to_s.empty?
              UI.user_error!("Missing FIREBASE_TOKEN") if token.to_s.empty?

              args = ["firebase", "appdistribution:distribute", artifact_path, "--app", app_id, "--token", token]
              args += ["--groups", groups] unless groups.to_s.empty?
              args += ["--release-notes", release_notes] unless release_notes.to_s.empty?
              sh(*args)
            end

            desc "Build and upload Android app to Google Play"
            lane :release_android do
              build_android
              upload_to_play_store(
                package_name: ENV["FASTLANE_ANDROID_PACKAGE_NAME"] || #{ruby_literal(android_package_name)}
              )
            end

            desc "CI lane: fetch data, build Android, and distribute to Firebase"
            lane :ci_android do
              fetch_data
              build_android
              firebase_android
            end
          end

          platform :ios do
            desc "Build iOS IPA release for Flutter"
            lane :build_ios do
              sh("flutter", "pub", "get")
              sh("flutter", "build", "ipa", "--release")
            end

            desc "Distribute iOS build to Firebase App Distribution"
            lane :firebase_ios do |options|
              artifact_path = options[:artifact_path] || Dir["build/ios/ipa/*.ipa"].max_by { |file| File.mtime(file) }
              UI.user_error!("iOS artifact not found. Run build_ios first.") unless artifact_path

              app_id = options[:app_id] || ENV["FIREBASE_APP_ID_IOS"]
              token = ENV["FIREBASE_TOKEN"]
              groups = options[:groups] || ENV["FIREBASE_TESTER_GROUPS"]
              release_notes = options[:release_notes] || ENV["FIREBASE_RELEASE_NOTES"]

              UI.user_error!("Missing FIREBASE_APP_ID_IOS") if app_id.to_s.empty?
              UI.user_error!("Missing FIREBASE_TOKEN") if token.to_s.empty?

              args = ["firebase", "appdistribution:distribute", artifact_path, "--app", app_id, "--token", token]
              args += ["--groups", groups] unless groups.to_s.empty?
              args += ["--release-notes", release_notes] unless release_notes.to_s.empty?
              sh(*args)
            end

            desc "Build and upload iOS app to TestFlight"
            lane :release_ios do
              build_ios
              upload_to_testflight(skip_waiting_for_build_processing: true)
            end

            desc "CI lane: fetch data, build iOS, and distribute to Firebase"
            lane :ci_ios do
              fetch_data
              build_ios
              firebase_ios
            end
          end
        RUBY
      end

      def self.build_appfile(ios_bundle_id:, apple_id:, team_id:, itc_team_id:)
        lines = []
        lines << "# Autogenerated by configure_fastlane action from fastlane-plugin-fastlane_configurator"
        lines << %(app_identifier(ENV["FASTLANE_APP_IDENTIFIER"] || #{ruby_literal(ios_bundle_id)}))
        lines << build_optional_setting("apple_id", "FASTLANE_APPLE_ID", apple_id)
        lines << build_optional_setting("team_id", "FASTLANE_TEAM_ID", team_id)
        lines << build_optional_setting("itc_team_id", "FASTLANE_ITC_TEAM_ID", itc_team_id)

        "#{lines.compact.join("\n")}\n"
      end

      def self.build_optional_setting(method_name, env_key, value)
        if value
          %(#{method_name}(ENV["#{env_key}"] || #{ruby_literal(value)}))
        else
          %(#{method_name}(ENV["#{env_key}"]) if ENV["#{env_key}"])
        end
      end

      def self.build_env_file(ios_bundle_id:, android_package_name:, apple_id:, team_id:, itc_team_id:)
        <<~ENV
          # Autogenerated by configure_fastlane action
          FASTLANE_APP_IDENTIFIER=#{ios_bundle_id}
          FASTLANE_ANDROID_PACKAGE_NAME=#{android_package_name}
          FASTLANE_APPLE_ID=#{apple_id || ""}
          FASTLANE_TEAM_ID=#{team_id || ""}
          FASTLANE_ITC_TEAM_ID=#{itc_team_id || ""}
          GITHUB_REPOSITORY=
          FIREBASE_TOKEN=
          FIREBASE_APP_ID_ANDROID=
          FIREBASE_APP_ID_IOS=
          FIREBASE_TESTER_GROUPS=qa
          FIREBASE_RELEASE_NOTES=Automated distribution from Fastlane
        ENV
      end

      def self.build_github_workflow(ci_branch)
        <<~YAML
          name: Mobile Delivery

          on:
            workflow_dispatch:
            push:
              branches:
                - #{ci_branch}

          jobs:
            android:
              runs-on: ubuntu-latest
              env:
                GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
                GITHUB_REPOSITORY: ${{ github.repository }}
                FIREBASE_TOKEN: ${{ secrets.FIREBASE_TOKEN }}
                FIREBASE_APP_ID_ANDROID: ${{ secrets.FIREBASE_APP_ID_ANDROID }}
                FIREBASE_TESTER_GROUPS: ${{ vars.FIREBASE_TESTER_GROUPS }}

              steps:
                - name: Checkout
                  uses: actions/checkout@v4

                - name: Setup Java
                  uses: actions/setup-java@v4
                  with:
                    distribution: temurin
                    java-version: "17"

                - name: Setup Flutter
                  uses: subosito/flutter-action@v2
                  with:
                    channel: stable

                - name: Setup Ruby
                  uses: ruby/setup-ruby@v1
                  with:
                    bundler-cache: true

                - name: Install Firebase CLI
                  run: npm install -g firebase-tools

                - name: Fetch Dart dependencies
                  run: flutter pub get

                - name: Generate fastlane config
                  run: bundle exec fastlane run configure_fastlane project_root:"${{ github.workspace }}" configure_ci:false configure_env:false

                - name: Run Android CI lane
                  run: bundle exec fastlane android ci_android

            ios:
              if: ${{ vars.ENABLE_IOS == 'true' }}
              runs-on: macos-latest
              env:
                GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
                GITHUB_REPOSITORY: ${{ github.repository }}
                FIREBASE_TOKEN: ${{ secrets.FIREBASE_TOKEN }}
                FIREBASE_APP_ID_IOS: ${{ secrets.FIREBASE_APP_ID_IOS }}
                FIREBASE_TESTER_GROUPS: ${{ vars.FIREBASE_TESTER_GROUPS }}

              steps:
                - name: Checkout
                  uses: actions/checkout@v4

                - name: Setup Flutter
                  uses: subosito/flutter-action@v2
                  with:
                    channel: stable

                - name: Setup Ruby
                  uses: ruby/setup-ruby@v1
                  with:
                    bundler-cache: true

                - name: Install Firebase CLI
                  run: npm install -g firebase-tools

                - name: Fetch Dart dependencies
                  run: flutter pub get

                - name: Generate fastlane config
                  run: bundle exec fastlane run configure_fastlane project_root:"${{ github.workspace }}" configure_ci:false configure_env:false

                - name: Run iOS CI lane
                  run: bundle exec fastlane ios ci_ios
        YAML
      end

      def self.infer_ios_bundle_id(project_root)
        pbxproj = File.join(project_root, "ios", "Runner.xcodeproj", "project.pbxproj")
        return nil unless File.exist?(pbxproj)

        ids = File.read(pbxproj).scan(/PRODUCT_BUNDLE_IDENTIFIER\s*=\s*([^;]+);/).flatten.map do |value|
          value.strip.delete('"')
        end

        ids.find { |value| !value.include?("RunnerTests") && !value.include?("$(") }
      end

      def self.infer_android_package_name(project_root)
        gradle_kts = File.join(project_root, "android", "app", "build.gradle.kts")
        gradle = File.join(project_root, "android", "app", "build.gradle")
        manifest = File.join(project_root, "android", "app", "src", "main", "AndroidManifest.xml")

        if File.exist?(gradle_kts)
          match = File.read(gradle_kts).match(/applicationId\s*=\s*"([^"]+)"/)
          return match[1] if match
        end

        if File.exist?(gradle)
          match = File.read(gradle).match(/applicationId\s+["']([^"']+)["']/)
          return match[1] if match
        end

        if File.exist?(manifest)
          match = File.read(manifest).match(/package\s*=\s*"([^"]+)"/)
          return match[1] if match
        end

        nil
      end

      def self.ruby_literal(value)
        value.to_s.inspect
      end
    end
  end
end
