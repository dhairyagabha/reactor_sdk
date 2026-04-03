# frozen_string_literal: true

module ReactorSDK
  module Resources
    class ComprehensiveExtension < ComprehensiveResource
      attr_reader :data_elements, :rule_components, :rules

      def initialize(resource:, data_elements:, rule_components:, rules:)
        super(resource: resource)
        @data_elements = Array(data_elements)
        @rule_components = Array(rule_components)
        @rules = Array(rules)
      end

      def associated_records
        (@data_elements + @rule_components + @rules).uniq
      end

      def normalized_payload
        payload = normalized_resource_payload
        payload['associations'] = {
          'data_elements' => summaries_for(@data_elements),
          'rule_components' => summaries_for(@rule_components),
          'rules' => summaries_for(@rules)
        }
        payload
      end
    end
  end
end
