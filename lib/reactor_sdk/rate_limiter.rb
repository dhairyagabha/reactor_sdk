# frozen_string_literal: true

##
# @file rate_limiter.rb
# @description Token bucket rate limiter for Reactor API requests.
#
#   Adobe enforces a limit of 120 requests per minute per access token.
#   This class implements a token bucket algorithm — the bucket starts
#   full and refills proportionally over time. When empty, the caller
#   blocks until a token is available.
#
#   One RateLimiter instance is created per ReactorSDK::Client so that
#   different client instances do not share a limit.
#
# @domain Infrastructure
#

module ReactorSDK
  class RateLimiter
    # Adobe's documented rate limit per access token
    MAX_REQUESTS_PER_MINUTE = 120

    # The window over which the limit applies
    INTERVAL_SECONDS = 60.0

    ##
    # Initializes a full token bucket.
    # The first MAX_REQUESTS_PER_MINUTE calls proceed without any delay.
    #
    def initialize
      @mutex     = Mutex.new
      @tokens    = MAX_REQUESTS_PER_MINUTE
      @last_tick = Time.now.utc
    end

    ##
    # Acquires one token from the bucket, blocking if the bucket is empty.
    # Refills the bucket based on elapsed time before checking availability.
    #
    # @return [void]
    #
    def acquire
      @mutex.synchronize do
        refill
        if @tokens >= 1
          @tokens -= 1
        else
          sleep(seconds_per_token)
          refill
          @tokens -= 1
        end
      end
    end

    ##
    # Returns the number of tokens currently available.
    # Useful for monitoring and testing — not used internally by acquire.
    #
    # @return [Integer] Current token count
    #
    def available_tokens
      @mutex.synchronize do
        refill
        @tokens.floor
      end
    end

    private

    ##
    # Adds tokens proportional to time elapsed since the last tick.
    # Never exceeds MAX_REQUESTS_PER_MINUTE.
    #
    # @sideeffect Updates @tokens and @last_tick
    #
    def refill
      now        = Time.now.utc
      elapsed    = now - @last_tick
      new_tokens = (elapsed / INTERVAL_SECONDS) * MAX_REQUESTS_PER_MINUTE

      if new_tokens >= 1
        @tokens    = [@tokens + new_tokens.floor, MAX_REQUESTS_PER_MINUTE].min
        @last_tick = now
      end
    end

    ##
    # Calculates how long to wait for a single token to become available.
    #
    # @return [Float] Seconds to sleep
    #
    def seconds_per_token
      INTERVAL_SECONDS / MAX_REQUESTS_PER_MINUTE
    end
  end
end
