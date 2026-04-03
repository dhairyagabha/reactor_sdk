# frozen_string_literal: true

##
# @file resources/upstream_chain.rb
# @description Represents the full upstream lookup result for one resource.
#
#   This wrapper captures the target library context and the ordered upstream
#   entries that were inspected. It exists so callers can ask higher-level
#   questions such as:
#     - What revision does the target library currently contain?
#     - Which upstream library is the nearest match?
#     - Did the resource disappear entirely upstream?
#

module ReactorSDK
  module Resources
    class UpstreamChain
      include Enumerable

      attr_reader :resource_id,
                  :resource_type,
                  :property_id,
                  :target_library_id,
                  :target_resource,
                  :target_revision_id,
                  :entries

      def initialize(
        resource_id:,
        resource_type:,
        property_id:,
        target_library_id:,
        target_resource:,
        target_revision_id:,
        entries:
      )
        @resource_id = resource_id
        @resource_type = resource_type
        @property_id = property_id
        @target_library_id = target_library_id
        @target_resource = target_resource
        @target_revision_id = target_revision_id
        @entries = Array(entries)
      end

      ##
      # @yieldparam entry [ReactorSDK::Resources::UpstreamChainEntry]
      # @return [Array<ReactorSDK::Resources::UpstreamChainEntry>]
      #
      def each(&)
        @entries.each(&)
      end

      ##
      # @return [ReactorSDK::Resources::UpstreamChainEntry, nil]
      #
      def nearest_match
        @entries.find(&:present?)
      end

      ##
      # @return [Boolean] true when any upstream library contains the resource
      #
      def found?
        !nearest_match.nil?
      end

      ##
      # @return [String] Human-readable representation
      #
      def inspect
        '#<ReactorSDK::Resources::UpstreamChain ' \
          "resource_id=#{resource_id.inspect} " \
          "resource_type=#{resource_type.inspect} " \
          "target_library_id=#{target_library_id.inspect} " \
          "entries=#{entries.length}>"
      end
    end
  end
end
