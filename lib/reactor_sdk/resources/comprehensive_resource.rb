# frozen_string_literal: true

module ReactorSDK
  module Resources
    class ComprehensiveResource
      attr_reader :resource

      def initialize(resource:)
        @resource = resource
      end

      def associated_records
        []
      end

      def normalized_json
        ReactorSDK::ResourceNormalizer.to_json(normalized_payload)
      end

      protected

      def normalized_resource_payload
        ReactorSDK::ResourceNormalizer.normalize_resource(resource)
      end

      def summaries_for(resources)
        Array(resources).map { |item| ReactorSDK::ResourceNormalizer.summary(item) }
      end
    end
  end
end
