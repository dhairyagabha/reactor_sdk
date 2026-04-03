# frozen_string_literal: true

module ReactorSDK
  module Resources
    class LibraryComparisonEntry
      attr_reader :resource_id,
                  :resource_type,
                  :current_library_id,
                  :baseline_library_id,
                  :current_resource,
                  :baseline_resource,
                  :current_revision_id,
                  :baseline_revision_id,
                  :current_comprehensive_resource,
                  :baseline_comprehensive_resource

      def initialize(
        resource_id:,
        resource_type:,
        current_library_id:,
        baseline_library_id:,
        current_resource:,
        baseline_resource:,
        current_revision_id:,
        baseline_revision_id:,
        current_comprehensive_resource:,
        baseline_comprehensive_resource:
      )
        @resource_id = resource_id
        @resource_type = resource_type
        @current_library_id = current_library_id
        @baseline_library_id = baseline_library_id
        @current_resource = current_resource
        @baseline_resource = baseline_resource
        @current_revision_id = current_revision_id
        @baseline_revision_id = baseline_revision_id
        @current_comprehensive_resource = current_comprehensive_resource
        @baseline_comprehensive_resource = baseline_comprehensive_resource
      end

      def resource_name
        return current_resource.name if current_resource.respond_to?(:name)
        return baseline_resource.name if baseline_resource.respond_to?(:name)

        nil
      end

      def status
        return 'added' if added?
        return 'removed' if removed?
        return 'unchanged' if unchanged?

        'modified'
      end

      def added?
        present_in_current? && !present_in_baseline?
      end

      def removed?
        !present_in_current? && present_in_baseline?
      end

      def modified?
        present_in_current? && present_in_baseline? && !unchanged?
      end

      def unchanged?
        return false unless present_in_current? && present_in_baseline?

        same_revision? || same_normalized_payload?
      end

      def changed?
        !unchanged?
      end

      def present_in_current?
        !current_resource.nil?
      end

      def present_in_baseline?
        !baseline_resource.nil?
      end

      def current_normalized_payload
        current_comprehensive_resource&.normalized_payload
      end

      def baseline_normalized_payload
        baseline_comprehensive_resource&.normalized_payload
      end

      def current_normalized_json
        current_comprehensive_resource&.normalized_json.to_s
      end

      def baseline_normalized_json
        baseline_comprehensive_resource&.normalized_json.to_s
      end

      def changeset_document(position: nil)
        document = {
          path: changeset_path,
          language: 'json',
          old_content: baseline_normalized_json,
          new_content: current_normalized_json,
          metadata: changeset_metadata
        }
        document[:position] = position unless position.nil?
        document
      end

      private

      def same_revision?
        return false if current_revision_id.nil? || baseline_revision_id.nil?

        current_revision_id == baseline_revision_id
      end

      def same_normalized_payload?
        current_normalized_payload == baseline_normalized_payload
      end

      def changeset_path
        "reactor/#{resource_type}/#{resource_id}.json"
      end

      def changeset_metadata
        {
          resource_id: resource_id,
          resource_type: resource_type,
          resource_name: resource_name,
          status: status,
          current_library_id: current_library_id,
          baseline_library_id: baseline_library_id,
          current_revision_id: current_revision_id,
          baseline_revision_id: baseline_revision_id
        }.compact
      end
    end
  end
end
