# frozen_string_literal: true

module ReactorSDK
  module Resources
    class LibrarySnapshotIndex
      attr_reader :resource_by_id, :rule_components, :rule_components_by_rule_id

      def initialize(rules:, data_elements:, extensions:, rule_components_by_rule_id:)
        @rules = Array(rules)
        @data_elements = Array(data_elements)
        @extensions = Array(extensions)
        @rule_components_by_rule_id = normalize_rule_components(rule_components_by_rule_id)
        @rule_components = @rule_components_by_rule_id.values.flatten
        @resource_by_id = build_resource_index
        @data_elements_by_name = build_data_element_name_index
        @data_element_dependency_graph = build_data_element_dependency_graph
        @reverse_data_element_graph = invert_graph(@data_element_dependency_graph)
        @rule_dependency_graph = build_rule_dependency_graph
        @rules_by_data_element = invert_graph(@rule_dependency_graph)
        @extension_index = LibrarySnapshotExtensionIndex.new(
          data_elements: @data_elements,
          rule_components_by_rule_id: @rule_components_by_rule_id,
          find_resource: method(:find_resource),
          sort_rule_components: method(:sort_rule_components)
        )
      end

      def find_resource(resource_id)
        @resource_by_id[extract_id(resource_id)]
      end

      def rule_components_for_rule(rule_or_id)
        @rule_components_by_rule_id.fetch(extract_id(rule_or_id), [])
      end

      def referenced_data_elements_for(data_element_or_id)
        referenced_resource_ids(data_element_or_id).filter_map { |resource_id| find_resource(resource_id) }
      end

      def impacted_rules_for(data_element_or_id)
        impacted_rule_ids_for(data_element_or_id)
          .filter_map { |resource_id| find_resource(resource_id) }
          .sort_by { |rule| [rule.name.to_s, rule.id] }
      end

      def data_elements_for_extension(extension_or_id)
        @extension_index.data_elements_for(extract_id(extension_or_id))
      end

      def rule_components_for_extension(extension_or_id)
        @extension_index.rule_components_for(extract_id(extension_or_id))
      end

      def rules_for_extension(extension_or_id)
        @extension_index.rules_for(extract_id(extension_or_id))
      end

      private

      def normalize_rule_components(rule_components_by_rule_id)
        rule_components_by_rule_id.to_h do |rule_id, components|
          [rule_id, sort_rule_components(Array(components))]
        end
      end

      def sort_rule_components(components)
        components.sort_by do |component|
          [
            sortable_number(component.respond_to?(:rule_order) ? component.rule_order : nil),
            sortable_number(component.respond_to?(:order) ? component.order : nil),
            component.id
          ]
        end
      end

      def sortable_number(value)
        value.nil? ? Float::INFINITY : value.to_f
      end

      def build_resource_index
        (@rules + @data_elements + @extensions + @rule_components).each_with_object({}) do |resource, index|
          index[resource.id] ||= resource
        end
      end

      def build_data_element_name_index
        @data_elements.each_with_object({}) do |data_element, index|
          next unless data_element.respond_to?(:name)
          next if data_element.name.nil?

          index[data_element.name] = data_element
        end
      end

      def build_data_element_dependency_graph
        @data_elements.to_h do |data_element|
          names = ReactorSDK::ReferenceExtractor.extract_data_element_names(data_element)
          [data_element.id, resolve_data_element_names(names, excluding: data_element.id)]
        end
      end

      def build_rule_dependency_graph
        @rules.to_h do |rule|
          component_names = rule_components_for_rule(rule.id).flat_map do |component|
            ReactorSDK::ReferenceExtractor.extract_data_element_names(component)
          end
          [rule.id, resolve_data_element_names(component_names)]
        end
      end

      def invert_graph(graph)
        graph.each_with_object(new_set_index) do |(from_id, to_ids), inverse|
          Array(to_ids).each { |to_id| inverse[to_id] << from_id }
        end.transform_values(&:to_a)
      end

      def referenced_resource_ids(data_element_or_id)
        data_element_id = extract_id(data_element_or_id)
        Array(@data_element_dependency_graph[data_element_id])
      end

      def impacted_rule_ids_for(data_element_or_id)
        related_data_element_ids = transitive_data_element_ids(extract_id(data_element_or_id))

        related_data_element_ids.each_with_object(Set.new) do |data_element_id, impacted_rule_ids|
          Array(@rules_by_data_element[data_element_id]).each { |rule_id| impacted_rule_ids << rule_id }
        end.to_a
      end

      def transitive_data_element_ids(data_element_id)
        related_data_element_ids = Set[data_element_id]
        queue = [data_element_id]

        until queue.empty?
          current = queue.shift

          Array(@reverse_data_element_graph[current]).each do |dependent_id|
            next if related_data_element_ids.include?(dependent_id)

            related_data_element_ids << dependent_id
            queue << dependent_id
          end
        end

        related_data_element_ids
      end

      def new_set_index
        Hash.new { |hash, key| hash[key] = Set.new }
      end

      def resolve_data_element_names(names, excluding: nil)
        names.each_with_object(Set.new) do |name, resolved_ids|
          target = @data_elements_by_name[name]
          next if target.nil?
          next if target.id == excluding

          resolved_ids << target.id
        end.to_a.sort
      end

      def extract_id(resource_or_id)
        return resource_or_id.id if resource_or_id.respond_to?(:id)

        resource_or_id
      end
    end
  end
end
