# frozen_string_literal: true

##
# @file resources/upstream_chain_entry.rb
# @description Represents one upstream-library lookup for a single resource.
#
#   This object is not returned directly by the Adobe API. It is assembled by
#   ReactorSDK when resolving a resource across the ordered upstream library
#   chain. Each entry answers:
#     - which library was inspected
#     - which stage that library belongs to
#     - whether the resource exists in that library
#     - which revision ID and revision snapshot were found
#

module ReactorSDK
  module Resources
    class UpstreamChainEntry
      attr_reader :library, :stage, :resource, :revision_id, :revision

      def initialize(library:, stage:, resource:, revision_id:, revision:)
        @library = library
        @stage = stage
        @resource = resource
        @revision_id = revision_id
        @revision = revision
      end

      ##
      # @return [Boolean] true when the resource exists in this upstream library
      #
      def present?
        !@resource.nil?
      end

      ##
      # @return [Hash, nil] Point-in-time snapshot for the matched revision
      #
      def entity_snapshot
        @revision&.entity_snapshot
      end

      ##
      # @return [String] Human-readable representation
      #
      def inspect
        '#<ReactorSDK::Resources::UpstreamChainEntry ' \
          "library_id=#{library.id.inspect} " \
          "stage=#{stage.inspect} " \
          "resource_id=#{resource&.id.inspect} " \
          "revision_id=#{revision_id.inspect}>"
      end
    end
  end
end
