# frozen_string_literal: true

##
# @file resources/build.rb
# @description Represents an Adobe Launch Build resource.
#
#   A build is the compiled output of a library — the JavaScript bundle
#   that gets deployed to an environment. Builds are created by triggering
#   a library build and move through statuses: pending -> processing ->
#   succeeded or failed.
#
# @domain Resources
# @see https://developer.adobe.com/experience-platform/documentation/tags/api/endpoints/builds/
#

module ReactorSDK
  module Resources
    class Build < BaseResource
      # @return [String] Current build status
      #   One of: "pending", "processing", "succeeded", "failed", "rejected"
      attribute :status

      # @return [String] ISO8601 timestamp when the build was created
      attribute :created_at

      # @return [String] ISO8601 timestamp when the build was last updated
      attribute :updated_at

      ##
      # Returns true if the build completed successfully.
      #
      # @return [Boolean]
      #
      def succeeded?
        status == "succeeded"
      end

      ##
      # Returns true if the build is still in progress.
      #
      # @return [Boolean]
      #
      def pending?
        %w[pending processing].include?(status)
      end

      ##
      # Returns true if the build failed.
      #
      # @return [Boolean]
      #
      def failed?
        status == "failed"
      end

      ##
      # @return [String] Human-readable representation
      #
      def inspect
        "#<ReactorSDK::Resources::Build id=#{id.inspect} status=#{status.inspect}>"
      end
    end
  end
end
