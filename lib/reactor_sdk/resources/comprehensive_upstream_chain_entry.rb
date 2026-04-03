# frozen_string_literal: true

module ReactorSDK
  module Resources
    class ComprehensiveUpstreamChainEntry
      attr_reader :library, :stage, :resource, :revision_id, :revision, :comprehensive_resource

      def initialize(library:, stage:, resource:, revision_id:, revision:, comprehensive_resource:)
        @library = library
        @stage = stage
        @resource = resource
        @revision_id = revision_id
        @revision = revision
        @comprehensive_resource = comprehensive_resource
      end

      def present?
        !@resource.nil?
      end

      def entity_snapshot
        @revision&.entity_snapshot
      end

      def normalized_payload
        @comprehensive_resource&.normalized_payload
      end

      def normalized_json
        @comprehensive_resource&.normalized_json
      end
    end
  end
end
