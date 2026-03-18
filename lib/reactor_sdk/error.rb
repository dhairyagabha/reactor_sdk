# frozen_string_literal: true

##
# @file error.rb
# @description Typed error hierarchy for the ReactorSDK gem.
#
#   All errors inherit from ReactorSDK::Error so callers can rescue
#   broadly or narrowly depending on their needs.
#
#   Rescue broadly:
#     rescue ReactorSDK::Error => e
#
#   Rescue specifically:
#     rescue ReactorSDK::RateLimitError => e
#       sleep e.retry_after
#       retry
#
# @domain Infrastructure
#

module ReactorSDK
  ##
  # Base class for all ReactorSDK errors.
  # Every other error in this file inherits from this class.
  #
  class Error < StandardError
    # @return [Integer, nil] HTTP status code from the API response
    attr_reader :status

    # @return [Exception, nil] The original exception that caused this one
    attr_reader :cause

    ##
    # @param message [String]        Human-readable description of what went wrong
    # @param status  [Integer, nil]  HTTP status code from the API response
    # @param cause   [Exception, nil] Underlying exception if this wraps another error
    #
    def initialize(message, status: nil, cause: nil)
      super(message)
      @status = status
      @cause  = cause
    end
  end

  ##
  # Raised when Adobe IMS token fetch or refresh fails.
  # Most commonly caused by an incorrect client_id or client_secret.
  #
  class AuthenticationError < Error; end

  ##
  # Raised when the token is valid but lacks permission for the resource.
  # Most commonly caused by the org not having access to a property.
  #
  class AuthorizationError < Error; end

  ##
  # Raised when the requested Adobe resource does not exist (HTTP 404).
  #
  class ResourceNotFoundError < Error; end

  ##
  # Raised when a request payload fails Adobe's validation (HTTP 422).
  # Check validation_errors for field-level details returned by Adobe.
  #
  class UnprocessableEntityError < Error
    # @return [Array<Hash>] Validation error objects returned by the Adobe API
    attr_reader :validation_errors

    ##
    # @param message           [String]      Error description
    # @param validation_errors [Array<Hash>] Adobe API validation error objects
    # @param opts              [Hash]        Passed through to ReactorSDK::Error
    #
    def initialize(message, validation_errors: [], **)
      super(message, **)
      @validation_errors = validation_errors
    end
  end

  ##
  # Raised when the rate limit is hit after all retries are exhausted (HTTP 429).
  # The retry_after value is taken from Adobe's Retry-After response header.
  #
  class RateLimitError < Error
    # @return [Integer, nil] Seconds to wait before the next request
    attr_reader :retry_after

    ##
    # @param message     [String]       Error description
    # @param retry_after [Integer, nil] Seconds until rate limit resets
    # @param opts        [Hash]         Passed through to ReactorSDK::Error
    #
    def initialize(message, retry_after: nil, **)
      super(message, **)
      @retry_after = retry_after
    end
  end

  ##
  # Raised when Adobe returns a 5xx server error after all retries exhausted.
  #
  class ServerError < Error; end

  ##
  # Raised when an HTTP response body cannot be parsed as valid JSON.
  #
  class ParseError < Error; end

  ##
  # Raised when a required configuration value is missing or blank.
  # Caught at client initialization time — never mid-request.
  #
  class ConfigurationError < Error; end
end
