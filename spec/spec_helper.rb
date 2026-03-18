# frozen_string_literal: true

##
# @file spec_helper.rb
# @description RSpec configuration for the ReactorSDK test suite.
#
#   Sets up:
#   - VCR for recording and replaying real Adobe API interactions
#   - WebMock to block all real HTTP in tests unless a cassette is active
#   - Shared helpers for building test doubles
#
#   VCR cassettes live in spec/vcr_cassettes/
#   Fixtures (static JSON files) live in spec/fixtures/
#
#   To record a new cassette against the real API:
#     VCR_RECORD=new bundle exec rspec spec/path/to/spec.rb
#
#   To re-record an existing cassette:
#     VCR_RECORD=all bundle exec rspec spec/path/to/spec.rb
#

require "reactor_sdk"
require "vcr"
require "webmock/rspec"

# ── VCR configuration ────────────────────────────────────────────
VCR.configure do |config|
  config.cassette_library_dir = "spec/vcr_cassettes"
  config.hook_into :webmock
  config.configure_rspec_metadata!

  # Never allow real HTTP through unless a cassette is active
  config.allow_http_connections_when_no_cassette = false

  # Scrub sensitive values from recorded cassettes before saving
  config.filter_sensitive_data("<ADOBE_ACCESS_TOKEN>") do
    ENV.fetch("ADOBE_ACCESS_TOKEN", "test_access_token")
  end
  config.filter_sensitive_data("<ADOBE_CLIENT_ID>") do
    ENV.fetch("ADOBE_CLIENT_ID", "test_client_id")
  end
  config.filter_sensitive_data("<ADOBE_CLIENT_SECRET>") do
    ENV.fetch("ADOBE_CLIENT_SECRET", "test_client_secret")
  end
  config.filter_sensitive_data("<ADOBE_IMS_ORG_ID>") do
    ENV.fetch("ADOBE_IMS_ORG_ID", "test_org_id")
  end

  # Record mode — override with VCR_RECORD=all or VCR_RECORD=new
  record_mode = ENV.fetch("VCR_RECORD", "none").to_sym
  config.default_cassette_options = { record: record_mode }
end

# ── RSpec configuration ──────────────────────────────────────────
RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
  config.filter_run_when_matching :focus
  config.disable_monkey_patching!
  config.warnings = true
  config.order = :random
  Kernel.srand config.seed

  # ── Shared test helpers ────────────────────────────────────────

  ##
  # Builds a ReactorSDK::Client configured for testing.
  # Uses a stub IMS token URL so no real Adobe auth occurs.
  # WebMock stubs the token endpoint to return a fake token.
  #
  def test_client
    stub_request(:post, "http://localhost:9292/token")
      .to_return(
        status: 200,
        body: { access_token: "test_token", expires_in: 86_400 }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    ReactorSDK::Client.new(
      client_id: "test_client_id",
      client_secret: "test_client_secret",
      org_id: "test_org_id",
      ims_token_url: "http://localhost:9292/token"
    )
  end

  ##
  # Builds a minimal JSON:API response hash for a single resource.
  # Used to stub connection responses without hitting the real API.
  #
  # @param type       [String] JSON:API resource type (e.g. "properties")
  # @param id         [String] Resource ID
  # @param attributes [Hash]   Resource attributes
  # @return [Hash] JSON:API response body
  #
  def jsonapi_response(type:, id:, attributes: {})
    {
      "data" => {
        "id" => id,
        "type" => type,
        "attributes" => attributes
      }
    }
  end

  ##
  # Builds a minimal JSON:API list response hash for multiple resources.
  #
  # @param type    [String]        JSON:API resource type
  # @param items   [Array<Hash>]   Array of { id:, attributes: } hashes
  # @return [Hash] JSON:API list response body with no next page
  #
  def jsonapi_list_response(type:, items:)
    {
      "data" => items.map do |item|
        {
          "id" => item[:id],
          "type" => type,
          "attributes" => item[:attributes]
        }
      end,
      "links" => { "next" => nil }
    }
  end
end
