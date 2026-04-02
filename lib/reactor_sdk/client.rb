# frozen_string_literal: true

##
# @file client.rb
# @description Main entry point for the ReactorSDK gem.
#
#   Instantiate one client per Adobe org. The client wires together all
#   infrastructure and exposes every endpoint group as a named method.
#
# @example Basic usage
#   client = ReactorSDK::Client.new(
#     client_id:     ENV["ADOBE_CLIENT_ID"],
#     client_secret: ENV["ADOBE_CLIENT_SECRET"],
#     org_id:        ENV["ADOBE_IMS_ORG_ID"]
#   )
#
#   # Fetch hosts before creating an environment
#   hosts = client.hosts.list_for_property("PR123")
#   client.environments.create(
#     property_id: "PR123",
#     name:        "jsmith-dev",
#     stage:       "development",
#     host_id:     hosts.first.id
#   )
#

module ReactorSDK
  class Client
    ENDPOINT_CLASSES = {
      companies: Endpoints::Companies,
      properties: Endpoints::Properties,
      app_configurations: Endpoints::AppConfigurations,
      callbacks: Endpoints::Callbacks,
      secrets: Endpoints::Secrets,
      environments: Endpoints::Environments,
      hosts: Endpoints::Hosts,
      rules: Endpoints::Rules,
      rule_components: Endpoints::RuleComponents,
      data_elements: Endpoints::DataElements,
      extensions: Endpoints::Extensions,
      extension_packages: Endpoints::ExtensionPackages,
      extension_package_usage_authorizations: Endpoints::ExtensionPackageUsageAuthorizations,
      libraries: Endpoints::Libraries,
      builds: Endpoints::Builds,
      audit_events: Endpoints::AuditEvents,
      revisions: Endpoints::Revisions,
      profiles: Endpoints::Profiles,
      search: Endpoints::Search,
      notes: Endpoints::Notes
    }.freeze

    # @return [ReactorSDK::Endpoints::Companies]
    attr_reader :companies

    # @return [ReactorSDK::Endpoints::Properties]
    attr_reader :properties

    # @return [ReactorSDK::Endpoints::AppConfigurations]
    attr_reader :app_configurations

    # @return [ReactorSDK::Endpoints::Callbacks]
    attr_reader :callbacks

    # @return [ReactorSDK::Endpoints::Secrets]
    attr_reader :secrets

    # @return [ReactorSDK::Endpoints::Environments]
    attr_reader :environments

    # @return [ReactorSDK::Endpoints::Hosts]
    attr_reader :hosts

    # @return [ReactorSDK::Endpoints::Rules]
    attr_reader :rules

    # @return [ReactorSDK::Endpoints::RuleComponents]
    attr_reader :rule_components

    # @return [ReactorSDK::Endpoints::DataElements]
    attr_reader :data_elements

    # @return [ReactorSDK::Endpoints::Extensions]
    attr_reader :extensions

    # @return [ReactorSDK::Endpoints::ExtensionPackages]
    attr_reader :extension_packages

    # @return [ReactorSDK::Endpoints::ExtensionPackageUsageAuthorizations]
    attr_reader :extension_package_usage_authorizations

    # @return [ReactorSDK::Endpoints::Libraries]
    attr_reader :libraries

    # @return [ReactorSDK::Endpoints::Builds]
    attr_reader :builds

    # @return [ReactorSDK::Endpoints::AuditEvents]
    attr_reader :audit_events

    # @return [ReactorSDK::Endpoints::Revisions]
    attr_reader :revisions

    # @return [ReactorSDK::Endpoints::Profiles]
    attr_reader :profiles

    # @return [ReactorSDK::Endpoints::Search]
    attr_reader :search

    # @return [ReactorSDK::Endpoints::Notes]
    attr_reader :notes

    # @return [ReactorSDK::Configuration]
    attr_reader :config

    ##
    # Initializes the client and all infrastructure dependencies.
    #
    # @param client_id          [String]  Adobe Developer Console client ID
    # @param client_secret      [String]  Adobe Developer Console client secret
    # @param org_id             [String]  Adobe IMS organisation ID
    # @param base_url           [String]  Override Reactor API base URL (optional)
    # @param ims_token_url      [String]  Override IMS token URL — for testing (optional)
    # @param timeout            [Integer] HTTP timeout in seconds (optional)
    # @param logger             [Logger]  Custom logger (optional)
    # @param auto_refresh_token [Boolean] Auto-refresh token before expiry (optional)
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
        client_id: client_id,
        client_secret: client_secret,
        org_id: org_id,
        base_url: base_url,
        ims_token_url: ims_token_url,
        timeout: timeout,
        logger: logger,
        auto_refresh_token: auto_refresh_token
      )

      build_infrastructure
      build_endpoints
    end

    private

    ##
    # Instantiates all infrastructure objects in dependency order.
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
    # Instantiates all endpoint group objects.
    # Add new endpoint groups here as they are implemented.
    #
    # @sideeffect Sets all endpoint attr_reader values
    #
    def build_endpoints
      deps = {
        connection: @connection,
        paginator: @paginator,
        parser: @parser
      }

      ENDPOINT_CLASSES.each do |name, endpoint_class|
        instance_variable_set(:"@#{name}", endpoint_class.new(**deps))
      end
    end
  end
end
