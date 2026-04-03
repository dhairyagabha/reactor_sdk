# frozen_string_literal: true

module ReactorSDK
  module Resources
    class ComprehensiveRule < ComprehensiveResource
      attr_reader :rule_components

      def initialize(resource:, rule_components:)
        super(resource: resource)
        @rule_components = Array(rule_components)
      end

      def associated_records
        @rule_components
      end

      def normalized_payload
        payload = normalized_resource_payload
        payload['associations'] = {
          'rule_components' => @rule_components.map { |component| ReactorSDK::ResourceNormalizer.normalize_resource(component) }
        }
        payload
      end
    end
  end
end
