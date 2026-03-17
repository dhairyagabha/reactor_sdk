# frozen_string_literal: true

require_relative "lib/reactor_sdk/version"

Gem::Specification.new do |spec|
  spec.name = "reactor_sdk"
  spec.version = ReactorSDK::VERSION
  spec.authors = ["Dhairya Gabhawala"]
  spec.email = ["gabhawaladhairya@gmail.com"]

  spec.summary     = "Ruby SDK for the Adobe Launch Reactor API"
  spec.description = <<~DESC
    A production-ready Ruby SDK for the Adobe Launch (Data Collection)
    Reactor API v1. Handles OAuth Server-to-Server authentication,
    JSON:API response parsing, cursor-based pagination, per-org rate
    limiting, retry logic, and a typed error hierarchy.
  DESC
  spec.homepage = "https://github.com/dhairyagabha/reactor-sdk"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2.0"

  spec.metadata = {
    "homepage_uri"          => spec.homepage,
    "source_code_uri"       => spec.homepage,
    "changelog_uri"         => "#{spec.homepage}/blob/main/CHANGELOG.md",
    "rubygems_mfa_required" => "true"
  }
  
  # Only include what belongs in the published gem
  spec.files = Dir.glob(%w[
    lib/**/*.rb
    sig/**/*.rbs
    LICENSE.txt
    README.md
    CHANGELOG.md
    reactor_sdk.gemspec
  ])

  spec.require_paths = ["lib"]

  # ── Runtime dependencies ─────────────────────────────────────────
  # HTTP client with middleware support
  spec.add_dependency "faraday",          "~> 2.9"
  # Automatic retry on 429 and 5xx responses
  spec.add_dependency "faraday-retry",    "~> 2.2"
  # Net::HTTP adapter for Faraday
  spec.add_dependency "faraday-net_http", "~> 3.3"

  # ── Development dependencies ─────────────────────────────────────
  # Test framework
  spec.add_development_dependency "rspec",         "~> 3.13"
  # Record and replay real HTTP interactions in tests
  spec.add_development_dependency "vcr",           "~> 6.3"
  # Block real HTTP in tests
  spec.add_development_dependency "webmock",       "~> 3.23"
  # Code style enforcement
  spec.add_development_dependency "rubocop",       "~> 1.65"
  spec.add_development_dependency "rubocop-rspec", "~> 3.0"
  # Documentation generation
  spec.add_development_dependency "yard",          "~> 0.9"
  # Rake task runner
  spec.add_development_dependency "rake",          "~> 13.0"
end
