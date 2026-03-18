# frozen_string_literal: true

##
# @file client.rb
# @description Main entry point for the ReactorSDK gem.
#
#   Instantiate one client per Adobe org. The client wires together
#   all infrastructure (configuration, authentication, rate limiting,
#   connection, pagination, parsing) and exposes every endpoint group
#   as a named method.
#
#   All dependencies are constructed internally — callers only need to
#   provide their Adobe credentials. Advanced users can override any
#   dependency by passing keyword arguments to the constructor.
#
# @domain Public API
#
# @example Basic usage
#   client = ReactorSDK::Client.new(
#     client_id:     ENV["ADOBE_CLIENT_ID"],
#     client_secret: ENV["ADOBE_CLIENT_SECRET"],
#     org_id:        ENV["ADOBE_IMS_ORG_ID"]
#   )
#
#   companies  = client.companies.list
#   properties = client.properties.list_for_company(companies.first.id)
#   rules      = client.rules.list_for_property(properties.first.id)
#   library    = client.libraries.find_with_resources("LB123")
#   revision   = client.revisions.find("RE123")
#

module ReactorSDK
  class Client
    # @return [ReactorSDK::Endpoints::Companies]
    attr_reader :companies

    # @return [ReactorSDK::Endpoints::Properties]
    attr_reader :properties

    # @return [ReactorSDK::Endpoints::Environments]
    attr_reader :environments

    # @return [ReactorSDK::Endpoints::Rules]
    attr_reader :rules

    # @return [ReactorSDK::Endpoints::RuleComponents]
    attr_reader :rule_components

    # @return [ReactorSDK::Endpoints::DataElements]
    attr_reader :data_elements

    # @return [ReactorSDK::Endpoints::Extensions]
    attr_reader :extensions

    # @return [ReactorSDK::Endpoints::Libraries]
    attr_reader :libraries

    # @return [ReactorSDK::Endpoints::Builds]
    attr_reader :builds

    # @return [ReactorSDK::Endpoints::AuditEvents]
    attr_reader :audit_events

    # @return [ReactorSDK::Endpoints::Revisions]
    attr_reader :revisions

    # @return [ReactorSDK::Configuration] The configuration used by this client
    attr_reader :config

    ##
    # Initializes the client and all infrastructure dependencies.
    # Raises immediately if credentials are missing — never mid-request.
    #
    # @param client_id          [String]  Adobe Developer Console client ID
    # @param client_secret      [String]  Adobe Developer Console client secret
    # @param org_id             [String]  Adobe IMS organisation ID
    # @param base_url           [String]  Override Reactor API base URL (optional)
    # @param ims_token_url      [String]  Override IMS token URL — for testing (optional)
    # @param timeout            [Integer] HTTP timeout in seconds (optional, default: 30)
    # @param logger             [Logger]  Custom logger — logs HTTP calls if provided (optional)
    # @param auto_refresh_token [Boolean] Auto-refresh token before expiry (optional, default: true)
    # @raise [ReactorSDK::ConfigurationError] if any required credential is blank
    #
    def initialize(
      client_id:,
      client_secret:,
      org_id:,
      base_url:           Configuration::DEFAULT_BASE_URL,
      ims_token_url:      Authentication::IMS_TOKEN_URL,
      timeout:            Configuration::DEFAULT_TIMEOUT,
      logger:             nil,
      auto_refresh_token: true
    )
      @config = Configuration.new(
        client_id:          client_id,
        client_secret:      client_secret,
        org_id:             org_id,
        base_url:           base_url,
        ims_token_url:      ims_token_url,
        timeout:            timeout,
        logger:             logger,
        auto_refresh_token: auto_refresh_token
      )

      build_infrastructure
      build_endpoints
    end

    private

    ##
    # Instantiates all infrastructure objects in dependency order.
    # Called once during initialization before endpoints are built.
    #
    # @sideeffect Sets @auth, @rate_limiter, @connection, @paginator, @parser
    #
    def build_infrastructure
      @auth         = Authentication.new(@config)
      @rate_limiter = RateLimiter.new
      @connection   = Connection.new(@config, @auth, @rate_limiter)
      @paginator    = Paginator.new(@connection)
      @parser       = ResponseParser.new
    end

    ##
    # Instantiates all endpoint group objects and assigns them to readers.
    # Called once during initialization after infrastructure is ready.
    # Add new endpoint groups here as they are implemented.
    #
    # @sideeffect Sets all endpoint attr_reader values
    #
    def build_endpoints
      deps = {
        connection: @connection,
        paginator:  @paginator,
        parser:     @parser
      }

      @companies       = Endpoints::Companies.new(**deps)
      @properties      = Endpoints::Properties.new(**deps)
      @environments    = Endpoints::Environments.new(**deps)
      @rules           = Endpoints::Rules.new(**deps)
      @rule_components = Endpoints::RuleComponents.new(**deps)
      @data_elements   = Endpoints::DataElements.new(**deps)
      @extensions      = Endpoints::Extensions.new(**deps)
      @libraries       = Endpoints::Libraries.new(**deps)
      @builds          = Endpoints::Builds.new(**deps)
      @audit_events    = Endpoints::AuditEvents.new(**deps)
      @revisions       = Endpoints::Revisions.new(**deps)
    end
  end
end
