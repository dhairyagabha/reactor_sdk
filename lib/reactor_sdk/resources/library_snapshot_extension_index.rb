# frozen_string_literal: true

module ReactorSDK
  module Resources
    class LibrarySnapshotExtensionIndex
      def initialize(data_elements:, rule_components_by_rule_id:, find_resource:, sort_rule_components:)
        @data_elements = Array(data_elements)
        @rule_components_by_rule_id = rule_components_by_rule_id
        @find_resource = find_resource
        @sort_rule_components = sort_rule_components
        @data_elements_by_extension = build_data_elements_index
        @rule_components_by_extension = build_rule_components_index
        @rules_by_extension = build_rules_index
      end

      def data_elements_for(extension_id)
        @data_elements_by_extension.fetch(extension_id, [])
      end

      def rule_components_for(extension_id)
        @rule_components_by_extension.fetch(extension_id, [])
      end

      def rules_for(extension_id)
        @rules_by_extension.fetch(extension_id, [])
      end

      private

      def build_data_elements_index
        group_by_relationship(@data_elements, 'extension').transform_values do |items|
          items.sort_by { |item| [item.name.to_s, item.id] }
        end
      end

      def build_rule_components_index
        group_by_relationship(@rule_components_by_rule_id.values.flatten, 'extension')
          .transform_values { |items| @sort_rule_components.call(items) }
      end

      def build_rules_index
        rules_by_extension = @rule_components_by_rule_id.each_with_object(new_set_index) do |rule_entry, index|
          rule_id, components = rule_entry
          rule = @find_resource.call(rule_id)
          next if rule.nil?

          components.each do |component|
            extension_id = component.relationship_id('extension')
            index[extension_id] << rule unless extension_id.nil?
          end
        end

        rules_by_extension.transform_values do |items|
          items.to_a.sort_by { |rule| [rule.name.to_s, rule.id] }
        end
      end

      def group_by_relationship(resources, relationship_name)
        resources.each_with_object(Hash.new { |hash, key| hash[key] = [] }) do |resource, grouped_resources|
          relationship_id = resource.relationship_id(relationship_name)
          grouped_resources[relationship_id] << resource unless relationship_id.nil?
        end
      end

      def new_set_index
        Hash.new { |hash, key| hash[key] = Set.new }
      end
    end
  end
end
