# frozen_string_literal: true

module ReactorSDK
  class LibraryComparisonBuilder
    RESOURCE_TYPE_ORDER = {
      'rules' => 0,
      'data_elements' => 1,
      'extensions' => 2
    }.freeze

    def initialize(snapshot_loader:)
      @snapshot_loader = snapshot_loader
    end

    def build(current_library_id, baseline_library_id:, property_id:)
      current_snapshot = @snapshot_loader.call(current_library_id, property_id: property_id)
      baseline_snapshot = @snapshot_loader.call(baseline_library_id, property_id: property_id)

      Resources::LibraryComparison.new(
        current_library_id: current_library_id,
        baseline_library_id: baseline_library_id,
        property_id: property_id,
        current_snapshot: current_snapshot,
        baseline_snapshot: baseline_snapshot,
        entries: build_entries(current_snapshot, baseline_snapshot)
      )
    end

    private

    def build_entries(current_snapshot, baseline_snapshot)
      comparable_resource_ids(current_snapshot, baseline_snapshot)
        .map { |resource_id| build_entry(current_snapshot, baseline_snapshot, resource_id) }
        .sort_by { |entry| entry_sort_key(entry) }
    end

    def comparable_resource_ids(current_snapshot, baseline_snapshot)
      (current_snapshot.top_level_resources.map(&:id) + baseline_snapshot.top_level_resources.map(&:id)).uniq
    end

    def build_entry(current_snapshot, baseline_snapshot, resource_id)
      current_resource = current_snapshot.find_resource(resource_id)
      baseline_resource = baseline_snapshot.find_resource(resource_id)
      resource_type = current_resource&.type || baseline_resource&.type

      Resources::LibraryComparisonEntry.new(
        resource_id: resource_id,
        resource_type: resource_type,
        current_library_id: current_snapshot.library.id,
        baseline_library_id: baseline_snapshot.library.id,
        current_resource: current_resource,
        baseline_resource: baseline_resource,
        current_revision_id: current_snapshot.resource_revision_id(resource_id),
        baseline_revision_id: baseline_snapshot.resource_revision_id(resource_id),
        current_comprehensive_resource: comprehensive_resource_for(current_snapshot, resource_id, resource_type),
        baseline_comprehensive_resource: comprehensive_resource_for(baseline_snapshot, resource_id, resource_type)
      )
    end

    def comprehensive_resource_for(snapshot, resource_id, resource_type)
      return nil if resource_type.nil?

      snapshot.comprehensive_resource(resource_id, resource_type: resource_type)
    end

    def entry_sort_key(entry)
      [
        RESOURCE_TYPE_ORDER.fetch(entry.resource_type, RESOURCE_TYPE_ORDER.length),
        entry.resource_name.to_s,
        entry.resource_id
      ]
    end
  end
end
