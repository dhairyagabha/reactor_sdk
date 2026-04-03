# frozen_string_literal: true

module ReactorSDK
  module Resources
    class ComprehensiveUpstreamChain
      include Enumerable

      attr_reader :resource_id,
                  :resource_type,
                  :property_id,
                  :target_library_id,
                  :target_resource,
                  :target_revision_id,
                  :target_comprehensive_resource,
                  :entries

      def initialize(
        resource_id:,
        resource_type:,
        property_id:,
        target_library_id:,
        target_resource:,
        target_revision_id:,
        target_comprehensive_resource:,
        entries:
      )
        @resource_id = resource_id
        @resource_type = resource_type
        @property_id = property_id
        @target_library_id = target_library_id
        @target_resource = target_resource
        @target_revision_id = target_revision_id
        @target_comprehensive_resource = target_comprehensive_resource
        @entries = Array(entries)
      end

      def each(&)
        @entries.each(&)
      end

      def nearest_match
        @entries.find(&:present?)
      end

      def found?
        !nearest_match.nil?
      end
    end
  end
end
