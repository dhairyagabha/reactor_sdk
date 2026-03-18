# frozen_string_literal: true

##
# @file connection.rb
# @description Authenticated Faraday HTTP connection for the Reactor API.
#
#   Responsibilities:
#   - Injects required Adobe auth headers on every request
#   - Enforces rate limiting via RateLimiter before every request
#   - Retries automatically on 429 and 5xx via faraday-retry middleware
#   - Translates HTTP error status codes into typed ReactorSDK errors
#   - Parses JSON responses into Ruby hashes
#
#   Required headers injected on every request:
#     Authorization:   Bearer {token}
#     x-api-key:       {client_id}
#     x-gw-ims-org-id: {org_id}
#     Accept:          application/vnd.api+json;revision=1
#     Content-Type:    application/vnd.api+json
#
#   Note on delete_relationship vs delete:
#     Standard DELETE requests have no body (used for resource deletion).
#     JSON:API relationship DELETE requests require a body identifying which
#     members to remove. delete_relationship handles this case by sending
#     a DELETE with a JSON body via a custom Faraday request block.
#
# @domain Infrastructure
# @depends ReactorSDK::Authentication, ReactorSDK::RateLimiter
#

module ReactorSDK
  class Connection
    # Pins the Reactor API to version 1 on every request.
    # Required by Adobe — omitting this may route to an unstable revision.
    ACCEPT_HEADER = "application/vnd.api+json;revision=1"

    # Required content type for all write requests (POST, PATCH, DELETE with body)
    CONTENT_TYPE = "application/vnd.api+json"

    ##
    # @param config       [ReactorSDK::Configuration] SDK configuration
    # @param auth         [ReactorSDK::Authentication] Token provider
    # @param rate_limiter [ReactorSDK::RateLimiter]   Request throttler
    #
    def initialize(config, auth, rate_limiter = RateLimiter.new)
      @config       = config
      @auth         = auth
      @rate_limiter = rate_limiter
      @http         = build_faraday_connection
    end

    ##
    # Executes an authenticated GET request to the Reactor API.
    #
    # @param path   [String] Relative path (e.g. "/properties/PR123/rules")
    # @param params [Hash]   Optional query string parameters
    # @return [Hash, nil] Parsed JSON response body
    # @raise [ReactorSDK::Error] on non-2xx after all retries exhausted
    #
    def get(path, params: {})
      @rate_limiter.acquire
      response = @http.get(path, params) { |req| inject_headers(req) }
      handle_response(response)
    end

    ##
    # Executes an authenticated POST request to the Reactor API.
    #
    # @param path [String] Relative API path
    # @param body [Hash]   Request body — serialised to JSON automatically
    # @return [Hash, nil] Parsed JSON response body
    # @raise [ReactorSDK::Error] on non-2xx after all retries exhausted
    #
    def post(path, body)
      @rate_limiter.acquire
      response = @http.post(path, body.to_json) { |req| inject_headers(req) }
      handle_response(response)
    end

    ##
    # Executes an authenticated PATCH request to the Reactor API.
    #
    # @param path [String] Relative API path
    # @param body [Hash]   Partial update body — serialised to JSON automatically
    # @return [Hash, nil] Parsed JSON response body
    # @raise [ReactorSDK::Error] on non-2xx after all retries exhausted
    #
    def patch(path, body)
      @rate_limiter.acquire
      response = @http.patch(path, body.to_json) { |req| inject_headers(req) }
      handle_response(response)
    end

    ##
    # Executes an authenticated DELETE request to the Reactor API.
    # Used for resource deletion — sends no body.
    # Adobe returns 204 No Content on successful deletion.
    #
    # @param path [String] Relative API path
    # @return [nil] Always returns nil on success
    # @raise [ReactorSDK::Error] on non-2xx after all retries exhausted
    #
    def delete(path)
      @rate_limiter.acquire
      response = @http.delete(path) { |req| inject_headers(req) }
      handle_response(response)
    end

    ##
    # Executes an authenticated DELETE request with a JSON body.
    #
    # Used exclusively for JSON:API relationship removal — the Reactor API
    # requires a body on relationship DELETE requests to identify which
    # members to remove. Standard DELETE sends no body, so this method
    # constructs the request manually via a Faraday block.
    #
    # Example: removing specific rules from a library requires:
    #   DELETE /libraries/:id/relationships/rules
    #   Body: { "data": [{ "id": "RL123", "type": "rules" }] }
    #
    # @param path [String] Relative API path
    # @param body [Hash]   Relationship payload identifying members to remove
    # @return [nil] Always returns nil on success (Adobe returns 204)
    # @raise [ReactorSDK::Error] on non-2xx after all retries exhausted
    #
    def delete_relationship(path, body)
      @rate_limiter.acquire
      response = @http.run_request(:delete, path, body.to_json, {}) do |req|
        inject_headers(req)
      end
      handle_response(response)
    end

    private

    ##
    # Builds the Faraday connection with the full middleware stack.
    #
    # @return [Faraday::Connection]
    #
    def build_faraday_connection
      Faraday.new(url: @config.base_url) do |f|
        f.request :retry, {
          max: 3,
          interval: 1.0,
          interval_randomness: 0.5,
          backoff_factor: 2,
          retry_statuses: [429, 500, 502, 503, 504]
        }
        f.response :logger, @config.logger if @config.logger
        f.adapter  :net_http
        f.options.timeout      = @config.timeout
        f.options.open_timeout = 10
      end
    end

    ##
    # Injects all required Adobe authentication and versioning headers.
    #
    # @param req [Faraday::Request] Outgoing request — headers mutated in place
    # @sideeffect Modifies req.headers
    #
    def inject_headers(req)
      req.headers["Authorization"]   = "Bearer #{@auth.access_token}"
      req.headers["x-api-key"]       = @config.client_id
      req.headers["x-gw-ims-org-id"] = @config.org_id
      req.headers["Accept"]          = ACCEPT_HEADER
      req.headers["Content-Type"]    = CONTENT_TYPE
    end

    ##
    # Parses the response body and raises typed errors for non-2xx responses.
    #
    # @param response [Faraday::Response] Raw HTTP response
    # @return [Hash, nil] Parsed response body, or nil for 204 No Content
    # @raise [ReactorSDK::AuthenticationError]      on 401
    # @raise [ReactorSDK::AuthorizationError]       on 403
    # @raise [ReactorSDK::ResourceNotFoundError]    on 404
    # @raise [ReactorSDK::UnprocessableEntityError] on 422
    # @raise [ReactorSDK::RateLimitError]           on 429
    # @raise [ReactorSDK::ServerError]              on 5xx
    # @raise [ReactorSDK::ParseError]               if body is not valid JSON
    #
    def handle_response(response)
      return nil if response.status == 204

      body = parse_body(response.body)

      case response.status
      when 200..299
        body
      when 401
        raise AuthenticationError.new(
          "Unauthorized — check your Adobe IMS token",
          status: 401
        )
      when 403
        raise AuthorizationError.new(
          "Forbidden — token lacks permission for this resource",
          status: 403
        )
      when 404
        raise ResourceNotFoundError.new(
          "Resource not found: #{response.env.url.path}",
          status: 404
        )
      when 422
        raise UnprocessableEntityError.new(
          "Validation failed",
          validation_errors: Array(body&.dig("errors")),
          status: 422
        )
      when 429
        retry_after = response.headers["Retry-After"]&.to_i
        raise RateLimitError.new(
          "Rate limit exceeded — retry after #{retry_after} seconds",
          retry_after: retry_after,
          status: 429
        )
      when 500..599
        raise ServerError.new(
          "Adobe API server error (HTTP #{response.status})",
          status: response.status
        )
      else
        raise Error.new(
          "Unexpected response status: #{response.status}",
          status: response.status
        )
      end
    end

    ##
    # Parses a JSON string into a Ruby Hash.
    #
    # @param body [String] Raw response body string
    # @return [Hash, nil] Parsed hash or nil if body is blank
    # @raise [ReactorSDK::ParseError] if body is present but not valid JSON
    #
    def parse_body(body)
      return nil if body.nil? || body.strip.empty?

      JSON.parse(body)
    rescue JSON::ParserError => e
      raise ParseError.new(
        "Could not parse API response as JSON",
        cause: e
      )
    end
  end
end
