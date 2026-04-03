# frozen_string_literal: true

module ReactorSDK
  class LibrarySnapshotBuilder
    def initialize(library_loader:, revisions_endpoint:, rule_components_endpoint:)
      @library_loader = library_loader
      @revisions_endpoint = revisions_endpoint
      @rule_components_endpoint = rule_components_endpoint
    end

    def build(library_id, property_id:)
      library = @library_loader.call(library_id)

      Resources::LibrarySnapshot.new(
        property_id: property_id,
        library: library,
        rule_components_by_rule_id: build_rule_components_index(library)
      )
    end

    private

    def build_rule_components_index(library)
      Array(library.rules).to_h do |rule|
        [rule.id, build_rule_components_snapshot(rule)]
      end
    end

    def build_rule_components_snapshot(rule)
      current_components = @rule_components_endpoint.list_for_rule(rule.id)
      rule_component_ids = point_in_time_rule_component_ids(rule)
      return current_components if rule_component_ids.empty?

      current_components_by_id = current_components.to_h do |component|
        [component.id, component]
      end

      rule_component_ids.filter_map do |component_id|
        current_components_by_id[component_id] || find_rule_component(component_id)
      end.uniq
    end

    def point_in_time_rule_component_ids(rule)
      revision_id = current_revision_id_for(rule)
      return [] if revision_id.nil?

      revision = @revisions_endpoint.find(revision_id)
      Array(revision.entity_relationships.dig('rule_components', 'data')).filter_map { |item| item['id'] }.uniq
    rescue ReactorSDK::Error
      []
    end

    def current_revision_id_for(rule)
      return rule.revision_id if rule.respond_to?(:revision_id)
      return rule.relationship_id('latest_revision') if rule.respond_to?(:relationship_id)

      nil
    end

    def find_rule_component(rule_component_id)
      @rule_components_endpoint.find(rule_component_id)
    rescue ReactorSDK::ResourceNotFoundError
      nil
    end
  end
end
