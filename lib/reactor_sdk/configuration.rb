# frozen_string_literal: true

##
# @file configuration.rb
# @description Holds and validates all configuration for a ReactorSDK::Client.
#
#   Validated eagerly on initialization — raises immediately if required
#   values are missing rather than failing mid-request when it is harder
#   to diagnose.
#
#   The ims_token_url parameter exists specifically for testing — it allows
#   specs to point at a WebMock or VCR stub instead of the real Adobe IMS
#   endpoint without any monkey-patching.
#
# @domain Infrastructure
#

module ReactorSDK
  class Configuration
    # Default Reactor API base URL
    DEFAULT_BASE_URL = 'https://reactor.adobe.io'

    # Default HTTP timeout in seconds
    DEFAULT_TIMEOUT = 30

    # @return [String] Adobe Developer Console client ID
    attr_reader :client_id

    # @return [String] Adobe Developer Console client secret
    attr_reader :client_secret

    # @return [String] Adobe IMS organisation ID (format: XXXXX@AdobeOrg)
    attr_reader :org_id

    # @return [String] Reactor API base URL
    attr_reader :base_url

    # @return [String] Adobe IMS token endpoint URL — overridable for testing
    attr_reader :ims_token_url

    # @return [Integer] HTTP timeout in seconds
    attr_reader :timeout

    # @return [Logger, nil] Optional logger — if provided, HTTP calls are logged
    attr_reader :logger

    # @return [Boolean] Whether to auto-refresh the token before expiry
    attr_reader :auto_refresh_token

    ##
    # Initializes and validates SDK configuration.
    #
    # @param client_id           [String]  Adobe Developer Console client ID
    # @param client_secret       [String]  Adobe Developer Console client secret
    # @param org_id              [String]  Adobe IMS organisation ID
    # @param base_url            [String]  Override Reactor API base URL (optional)
    # @param ims_token_url       [String]  Override IMS token URL — for testing only (optional)
    # @param timeout             [Integer] HTTP timeout in seconds (optional)
    # @param logger              [Logger]  Custom logger instance (optional)
    # @param auto_refresh_token  [Boolean] Auto-refresh token before expiry.
    #   When false, the initial token is still fetched, but later expiry
    #   raises AuthenticationError instead of refreshing. (optional)
    # @raise [ReactorSDK::ConfigurationError] if any required value is blank
    #
    def initialize(
      client_id:,
      client_secret:,
      org_id:,
      base_url: DEFAULT_BASE_URL,
      ims_token_url: Authentication::IMS_TOKEN_URL,
      timeout: DEFAULT_TIMEOUT,
      logger: nil,
      auto_refresh_token: true
    )
      @client_id          = client_id
      @client_secret      = client_secret
      @org_id             = org_id
      @base_url           = base_url
      @ims_token_url      = ims_token_url
      @timeout            = timeout
      @logger             = logger
      @auto_refresh_token = auto_refresh_token

      validate!
    end

    private

    ##
    # Checks that all required fields are present and non-blank.
    #
    # @raise [ReactorSDK::ConfigurationError] if any required field is blank
    #
    def validate!
      %i[client_id client_secret org_id].each do |field|
        value = public_send(field)
        if value.nil? || value.strip.empty?
          raise ConfigurationError,
                "#{field} is required and cannot be blank"
        end
      end
    end
  end
end
