# frozen_string_literal: true

##
# @file authentication.rb
# @description Handles Adobe IMS OAuth Server-to-Server authentication.
#
#   Fetches and caches access tokens using the client_credentials grant.
#   Tokens are refreshed automatically when within REFRESH_BUFFER_SECONDS
#   of expiry. Thread-safe via Mutex.
#
#   Adobe deprecated JWT (Service Account) authentication on January 1 2025.
#   This implementation uses OAuth Server-to-Server only.
#
#   The token URL is read from config rather than hardcoded so that tests
#   can override it via Configuration's ims_token_url parameter without
#   any monkey-patching or global state changes.
#
# @domain Infrastructure
# @depends ReactorSDK::Configuration
#
# @see https://developer.adobe.com/developer-console/docs/guides/authentication/ServerToServerAuthentication/
#

module ReactorSDK
  class Authentication
    # Adobe IMS token endpoint — single global endpoint for all regions
    # Read by Configuration as its default value for ims_token_url
    IMS_TOKEN_URL = "https://ims-na1.adobelogin.com/ims/token/v3"

    # Refresh the token this many seconds before actual expiry.
    # Prevents edge cases where a token expires between check and use.
    REFRESH_BUFFER_SECONDS = 300

    # Required OAuth scopes for full Reactor API access
    REACTOR_SCOPE = [
      "openid",
      "AdobeID",
      "read_organizations",
      "additional_info.projectedProductContext"
    ].join(",").freeze

    ##
    # @param config [ReactorSDK::Configuration] SDK configuration instance
    #
    def initialize(config)
      @config       = config
      @token        = nil
      @token_expiry = nil
      @mutex        = Mutex.new
    end

    ##
    # Returns a valid access token, fetching or refreshing if necessary.
    # Thread-safe — uses a Mutex to prevent parallel token fetches in
    # multi-threaded environments such as Puma.
    #
    # @return [String] Valid Adobe IMS Bearer access token
    # @raise  [ReactorSDK::AuthenticationError] if the token request fails
    #
    def access_token
      @mutex.synchronize do
        fetch_token if token_expired?
        @token
      end
    end

    private

    ##
    # Returns true if the token is missing or within the refresh buffer window.
    #
    # @return [Boolean]
    #
    def token_expired?
      @token.nil? ||
        Time.now.utc >= (@token_expiry - REFRESH_BUFFER_SECONDS)
    end

    ##
    # Fetches a fresh access token from Adobe IMS using client_credentials grant.
    # Uses @config.ims_token_url so tests can intercept without hitting Adobe.
    #
    # @raise [ReactorSDK::AuthenticationError] if the IMS request fails
    # @sideeffect Sets @token and @token_expiry
    #
    def fetch_token
      response = Faraday.post(@config.ims_token_url, token_request_params)

      unless response.success?
        raise AuthenticationError.new(
          "Adobe IMS token request failed (HTTP #{response.status}). " \
          "Check your client_id and client_secret.",
          status: response.status
        )
      end

      parse_token_response(response.body)
    rescue Faraday::Error => e
      raise AuthenticationError.new(
        "Network error during token fetch: #{e.message}",
        cause: e
      )
    end

    ##
    # Builds the POST body parameters for the IMS token request.
    #
    # @return [Hash] Form-encoded parameters for the IMS endpoint
    #
    def token_request_params
      {
        grant_type: "client_credentials",
        client_id: @config.client_id,
        client_secret: @config.client_secret,
        scope: REACTOR_SCOPE
      }
    end

    ##
    # Parses the JSON response and stores the token and its expiry time.
    #
    # @param body [String] Raw JSON response body from Adobe IMS
    # @raise [ReactorSDK::AuthenticationError] if body is not valid JSON
    # @sideeffect Sets @token and @token_expiry
    #
    def parse_token_response(body)
      data          = JSON.parse(body)
      @token        = data.fetch("access_token")
      @token_expiry = Time.now.utc + data.fetch("expires_in").to_i
    rescue JSON::ParserError, KeyError => e
      raise AuthenticationError.new(
        "Could not parse Adobe IMS token response",
        cause: e
      )
    end
  end
end
