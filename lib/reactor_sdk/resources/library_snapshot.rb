# frozen_string_literal: true

module ReactorSDK
  module Resources
    class LibrarySnapshot
      attr_reader :property_id,
                  :library,
                  :rules,
                  :data_elements,
                  :extensions,
                  :rule_components,
                  :rule_components_by_rule_id,
                  :resource_by_id

      def initialize(property_id:, library:, rule_components_by_rule_id:)
        @property_id = property_id
        @library = library
        @rules = Array(library.rules)
        @data_elements = Array(library.data_elements)
        @extensions = Array(library.extensions)
        @index = LibrarySnapshotIndex.new(
          rules: @rules,
          data_elements: @data_elements,
          extensions: @extensions,
          rule_components_by_rule_id: rule_components_by_rule_id
        )
        @rule_components_by_rule_id = @index.rule_components_by_rule_id
        @rule_components = @index.rule_components
        @resource_by_id = @index.resource_by_id
      end

      def top_level_resources
        @top_level_resources ||= @rules + @data_elements + @extensions
      end

      def all_resources
        top_level_resources + @rule_components
      end

      def find_resource(resource_id)
        @index.find_resource(resource_id)
      end

      def rule_components_for_rule(rule_or_id)
        @index.rule_components_for_rule(rule_or_id)
      end

      def referenced_data_elements_for(data_element_or_id)
        @index.referenced_data_elements_for(data_element_or_id)
      end

      def impacted_rules_for(data_element_or_id)
        @index.impacted_rules_for(data_element_or_id)
      end

      def data_elements_for_extension(extension_or_id)
        @index.data_elements_for_extension(extension_or_id)
      end

      def rule_components_for_extension(extension_or_id)
        @index.rule_components_for_extension(extension_or_id)
      end

      def rules_for_extension(extension_or_id)
        @index.rules_for_extension(extension_or_id)
      end

      def resource_revision_id(resource_or_id)
        resource_id = extract_id(resource_or_id)
        resource = find_resource(resource_id)
        return nil if resource.nil?
        return resource.revision_id if resource.respond_to?(:revision_id)
        return @library.resource_index[resource_id] if @library.resource_index.key?(resource_id)
        return resource.relationship_id('latest_revision') if resource.respond_to?(:relationship_id)

        nil
      end

      def comprehensive_resource(resource_id, resource_type: nil)
        resource = find_resource(resource_id)
        return nil if resource.nil?

        build_comprehensive_resource(resource, resource_type || resource.type)
      end

      private

      def build_comprehensive_resource(resource, resource_type)
        case resource_type
        when 'rules'
          ComprehensiveRule.new(
            resource: resource,
            rule_components: rule_components_for_rule(resource.id)
          )
        when 'data_elements'
          ComprehensiveDataElement.new(
            resource: resource,
            referenced_data_elements: referenced_data_elements_for(resource.id),
            impacted_rules: impacted_rules_for(resource.id)
          )
        when 'extensions'
          ComprehensiveExtension.new(
            resource: resource,
            data_elements: data_elements_for_extension(resource.id),
            rule_components: rule_components_for_extension(resource.id),
            rules: rules_for_extension(resource.id)
          )
        end
      end

      def extract_id(resource_or_id)
        return resource_or_id.id if resource_or_id.respond_to?(:id)

        resource_or_id
      end
    end
  end
end
