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
# @domain Infrastructure
# @depends ReactorSDK::Authentication, ReactorSDK::RateLimiter
#

module ReactorSDK
  class Connection
    # Pins the Reactor API to version 1 on every request.
    ACCEPT_HEADER = 'application/vnd.api+json;revision=1'

    # Required content type for all write requests
    CONTENT_TYPE = 'application/vnd.api+json'

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
    # Executes an authenticated GET request.
    #
    # @param path   [String] Relative path
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
    # Executes an authenticated POST request.
    #
    # @param path [String] Relative API path
    # @param body [Hash]   Request body
    # @return [Hash, nil] Parsed JSON response body
    # @raise [ReactorSDK::Error] on non-2xx after all retries exhausted
    #
    def post(path, body)
      @rate_limiter.acquire
      response = @http.post(path, body.to_json) { |req| inject_headers(req) }
      handle_response(response)
    end

    ##
    # Executes an authenticated PATCH request.
    #
    # @param path [String] Relative API path
    # @param body [Hash]   Partial update body
    # @return [Hash, nil] Parsed JSON response body
    # @raise [ReactorSDK::Error] on non-2xx after all retries exhausted
    #
    def patch(path, body)
      @rate_limiter.acquire
      response = @http.patch(path, body.to_json) { |req| inject_headers(req) }
      handle_response(response)
    end

    ##
    # Executes an authenticated DELETE request with no body.
    #
    # @param path [String] Relative API path
    # @return [nil]
    # @raise [ReactorSDK::Error] on non-2xx after all retries exhausted
    #
    def delete(path)
      @rate_limiter.acquire
      response = @http.delete(path) { |req| inject_headers(req) }
      handle_response(response)
    end

    ##
    # Executes an authenticated DELETE request with a JSON body.
    # Used for JSON:API relationship removal.
    #
    # @param path [String] Relative API path
    # @param body [Hash]   Relationship payload
    # @return [nil]
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
    # Builds the Faraday connection with retry middleware.
    #
    # @return [Faraday::Connection]
    #
    def build_faraday_connection
      Faraday.new(url: @config.base_url) do |f|
        f.request :retry, retry_options
        f.response :logger, @config.logger if @config.logger
        f.adapter  :net_http
        f.options.timeout      = @config.timeout
        f.options.open_timeout = 10
      end
    end

    ##
    # Retry configuration for transient Adobe API failures.
    #
    # @return [Hash]
    #
    def retry_options
      {
        max: 3,
        interval: 1.0,
        interval_randomness: 0.5,
        backoff_factor: 2,
        retry_statuses: [429, 500, 502, 503, 504]
      }
    end

    ##
    # Injects required Adobe authentication and versioning headers.
    #
    # @param req [Faraday::Request] Outgoing request
    # @sideeffect Modifies req.headers
    #
    def inject_headers(req)
      req.headers['Authorization']   = "Bearer #{@auth.access_token}"
      req.headers['x-api-key']       = @config.client_id
      req.headers['x-gw-ims-org-id'] = @config.org_id
      req.headers['Accept']          = ACCEPT_HEADER
      req.headers['Content-Type']    = CONTENT_TYPE
    end

    ##
    # Parses the response and raises typed errors for non-2xx responses.
    #
    # @param response [Faraday::Response] Raw HTTP response
    # @return [Hash, nil] Parsed response body or nil for 204
    # @raise [ReactorSDK::Error] on non-2xx response
    #
    def handle_response(response)
      return nil if response.status == 204

      body = parse_body(response.body)
      return body if response.status.between?(200, 299)

      raise_error_for_status(response, body)
    end

    ##
    # Raises the appropriate typed error for a non-2xx response.
    # Extracts Adobe error detail from the response body when available.
    #
    # @param response [Faraday::Response] Raw HTTP response
    # @param body     [Hash, nil]         Parsed response body
    # @raise [ReactorSDK::Error]
    #
    def raise_error_for_status(response, body)
      raise_rate_limit_error(response) if response.status == 429

      raise build_error_for_status(response, body)
    end

    ##
    # Builds the appropriate typed error for a non-2xx response.
    #
    # @param response [Faraday::Response]
    # @param body     [Hash, nil]
    # @return [ReactorSDK::Error]
    #
    def build_error_for_status(response, body)
      adobe_message = extract_adobe_message(body)

      case response.status
      when 400, 422
        unprocessable_error(validation_message(response.status, adobe_message), body, status: response.status)
      when 401
        AuthenticationError.new('Unauthorized — check your Adobe IMS token', status: 401)
      when 403
        AuthorizationError.new('Forbidden — token lacks permission for this resource', status: 403)
      when 404
        ResourceNotFoundError.new("Resource not found: #{response.env.url.path}", status: 404)
      when 405
        method_not_allowed_error(response)
      when 409
        conflict_error(adobe_message)
      when 500..599
        ServerError.new("Adobe API server error (HTTP #{response.status})", status: response.status)
      else
        Error.new("Unexpected response status: #{response.status}", status: response.status)
      end
    end

    ##
    # Returns the default validation message for 400/422 responses.
    #
    # @param status        [Integer]
    # @param adobe_message [String, nil]
    # @return [String]
    #
    def validation_message(status, adobe_message)
      return adobe_message if adobe_message
      return 'Bad request — check payload structure and required relationships' if status == 400

      'Validation failed'
    end

    ##
    # Builds a validation-style error with the Adobe errors array attached.
    #
    # @param message [String]
    # @param body    [Hash, nil]
    # @param status  [Integer]
    # @return [ReactorSDK::UnprocessableEntityError]
    #
    def unprocessable_error(message, body, status:)
      UnprocessableEntityError.new(
        message,
        validation_errors: Array(body&.dig('errors')),
        status: status
      )
    end

    ##
    # Builds a 405 error with request context.
    #
    # @param response [Faraday::Response]
    # @return [ReactorSDK::Error]
    #
    def method_not_allowed_error(response)
      Error.new(
        'Method not allowed — check the correct endpoint for this operation. ' \
        "Adobe returned 405 for #{response.env.method.upcase} #{response.env.url.path}",
        status: 405
      )
    end

    ##
    # Builds a 409 conflict error with Launch-specific guidance.
    #
    # @param adobe_message [String, nil]
    # @return [ReactorSDK::Error]
    #
    def conflict_error(adobe_message)
      Error.new(
        adobe_message || 'Conflict — resource may need to be revised before this operation. ' \
                         'Call revise() on the resource before adding it to a library.',
        status: 409
      )
    end

    ##
    # Extracts a human-readable message from the Adobe error response body.
    # Adobe returns errors in JSON:API format under the "errors" array.
    #
    # @param body [Hash, nil] Parsed response body
    # @return [String, nil] First error detail or title, or nil if not present
    #
    def extract_adobe_message(body)
      return nil unless body.is_a?(Hash)

      errors = body['errors']
      return nil unless errors.is_a?(Array) && errors.any?

      first = errors.first
      first['detail'] || first['title']
    end

    ##
    # Raises a RateLimitError with retry_after from the response header.
    #
    # @param response [Faraday::Response]
    # @raise [ReactorSDK::RateLimitError]
    #
    def raise_rate_limit_error(response)
      retry_after = response.headers['Retry-After']&.to_i
      raise RateLimitError.new(
        "Rate limit exceeded — retry after #{retry_after} seconds",
        retry_after: retry_after,
        status: 429
      )
    end

    ##
    # Parses a JSON string into a Ruby Hash.
    #
    # @param body [String] Raw response body
    # @return [Hash, nil]
    # @raise [ReactorSDK::ParseError] if body is not valid JSON
    #
    def parse_body(body)
      return nil if body.nil? || body.strip.empty?

      JSON.parse(body)
    rescue JSON::ParserError => e
      raise ParseError.new('Could not parse API response as JSON', cause: e)
    end
  end
end
