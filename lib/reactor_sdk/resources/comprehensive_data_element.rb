# frozen_string_literal: true

module ReactorSDK
  module Resources
    class ComprehensiveDataElement < ComprehensiveResource
      attr_reader :referenced_data_elements, :impacted_rules

      def initialize(resource:, referenced_data_elements:, impacted_rules:)
        super(resource: resource)
        @referenced_data_elements = Array(referenced_data_elements)
        @impacted_rules = Array(impacted_rules)
      end

      def associated_records
        (@referenced_data_elements + @impacted_rules).uniq
      end

      def normalized_payload
        payload = normalized_resource_payload
        payload['associations'] = {
          'referenced_data_elements' => summaries_for(@referenced_data_elements),
          'impacted_rules' => summaries_for(@impacted_rules)
        }
        payload
      end
    end
  end
end
