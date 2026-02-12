# frozen_string_literal: true

require "fileutils"
require "json"
require "net/http"
require "open3"
require "time"
require "uri"

module Fastlane
  module Actions
    class FetchMobileDataAction < Action
      def self.run(params)
        project_root = File.expand_path(params[:project_root])
        output_path = normalized_value(params[:output_path]) || "fastlane/build_data.json"
        include_github = params[:include_github]

        github_repository = normalized_value(params[:github_repository]) || ENV["GITHUB_REPOSITORY"]
        github_token = normalized_value(params[:github_token]) || ENV["GITHUB_TOKEN"]

        version_name, version_code = read_flutter_version(project_root)

        payload = {
          "generated_at_utc" => Time.now.utc.iso8601,
          "project_root" => project_root,
          "app" => {
            "name" => read_flutter_package_name(project_root),
            "version_name" => version_name,
            "version_code" => version_code
          },
          "identifiers" => {
            "ios_bundle_id" => ConfigureFastlaneAction.infer_ios_bundle_id(project_root),
            "android_package_name" => ConfigureFastlaneAction.infer_android_package_name(project_root)
          },
          "git" => {
            "branch" => git_output(project_root, "rev-parse", "--abbrev-ref", "HEAD"),
            "sha" => git_output(project_root, "rev-parse", "HEAD"),
            "latest_tag" => git_output(project_root, "describe", "--tags", "--abbrev=0")
          }
        }

        payload["github"] = build_github_payload(github_repository, github_token) if include_github

        absolute_output_path = output_path.start_with?("/") ? output_path : File.join(project_root, output_path)
        FileUtils.mkdir_p(File.dirname(absolute_output_path))
        File.write(absolute_output_path, "#{JSON.pretty_generate(payload)}\n")

        UI.success("Build metadata written to #{absolute_output_path}")
        payload
      end

      def self.description
        "Fetch mobile project metadata for Fastlane, Firebase, and GitHub Actions"
      end

      def self.authors
        ["tolba"]
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(
            key: :project_root,
            env_name: "FL_FETCH_MOBILE_DATA_PROJECT_ROOT",
            description: "Root path of the mobile project",
            default_value: Dir.pwd,
            verify_block: proc do |value|
              UI.user_error!("project_root does not exist: #{value}") unless Dir.exist?(value)
            end
          ),
          FastlaneCore::ConfigItem.new(
            key: :output_path,
            env_name: "FL_FETCH_MOBILE_DATA_OUTPUT_PATH",
            description: "JSON output path for fetched metadata",
            default_value: "fastlane/build_data.json"
          ),
          FastlaneCore::ConfigItem.new(
            key: :include_github,
            env_name: "FL_FETCH_MOBILE_DATA_INCLUDE_GITHUB",
            description: "Include GitHub API data in output",
            is_string: false,
            default_value: true
          ),
          FastlaneCore::ConfigItem.new(
            key: :github_repository,
            env_name: "FL_FETCH_MOBILE_DATA_GITHUB_REPOSITORY",
            description: "GitHub repository in owner/repo format",
            optional: true
          ),
          FastlaneCore::ConfigItem.new(
            key: :github_token,
            env_name: "FL_FETCH_MOBILE_DATA_GITHUB_TOKEN",
            description: "GitHub token for authenticated API requests",
            optional: true,
            sensitive: true
          )
        ]
      end

      def self.return_value
        "Hash containing app, git, and optional GitHub metadata"
      end

      def self.details
        "Reads Flutter version and app identifiers, git metadata, and optional GitHub release/workflow info."
      end

      def self.example_code
        [
          "fetch_mobile_data",
          "fetch_mobile_data(output_path: \"fastlane/build_data.json\")",
          "fetch_mobile_data(include_github: false)"
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

      def self.read_flutter_version(project_root)
        pubspec = File.join(project_root, "pubspec.yaml")
        return [nil, nil] unless File.exist?(pubspec)

        line = File.read(pubspec).lines.find { |row| row.strip.start_with?("version:") }
        return [nil, nil] unless line

        raw = line.split(":", 2)[1].to_s.strip
        version_name, version_code = raw.split("+", 2)
        [version_name, version_code]
      end

      def self.read_flutter_package_name(project_root)
        pubspec = File.join(project_root, "pubspec.yaml")
        return nil unless File.exist?(pubspec)

        line = File.read(pubspec).lines.find { |row| row.strip.start_with?("name:") }
        return nil unless line

        line.split(":", 2)[1].to_s.strip
      end

      def self.git_output(project_root, *args)
        stdout, _stderr, status = Open3.capture3("git", *args, chdir: project_root)
        return nil unless status.success?

        output = stdout.to_s.strip
        output.empty? ? nil : output
      rescue StandardError
        nil
      end

      def self.build_github_payload(repository, token)
        return { "repository" => nil, "note" => "Set github_repository or GITHUB_REPOSITORY to fetch remote GitHub data" } if repository.nil?

        payload = { "repository" => repository }

        release_code, release_body = github_get("/repos/#{repository}/releases/latest", token)
        if release_code == 200
          payload["latest_release"] = {
            "tag" => release_body["tag_name"],
            "name" => release_body["name"],
            "published_at" => release_body["published_at"]
          }
        elsif release_code == 404
          payload["latest_release"] = nil
        else
          payload["latest_release_error"] = "GitHub API returned #{release_code} while reading latest release"
        end

        run_code, run_body = github_get("/repos/#{repository}/actions/runs?per_page=1", token)
        if run_code == 200
          run = run_body.fetch("workflow_runs", []).first
          payload["latest_workflow_run"] = run.nil? ? nil : {
            "id" => run["id"],
            "name" => run["name"],
            "status" => run["status"],
            "conclusion" => run["conclusion"],
            "created_at" => run["created_at"],
            "url" => run["html_url"]
          }
        else
          payload["latest_workflow_error"] = "GitHub API returned #{run_code} while reading workflow runs"
        end

        payload
      end

      def self.github_get(path, token)
        uri = URI.parse("https://api.github.com#{path}")
        request = Net::HTTP::Get.new(uri)
        request["Accept"] = "application/vnd.github+json"
        request["User-Agent"] = "fastlane-plugin-fastlane_configurator"
        request["Authorization"] = "Bearer #{token}" if token

        response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, read_timeout: 15) do |http|
          http.request(request)
        end

        code = response.code.to_i
        body = response.body.to_s
        parsed_body = body.empty? ? {} : JSON.parse(body)
        [code, parsed_body]
      rescue StandardError => error
        [0, { "error" => error.message }]
      end
    end
  end
end
