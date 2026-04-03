# frozen_string_literal: true

module ReactorSDK
  module Resources
    class LibraryComparison
      include Enumerable

      attr_reader :current_library_id,
                  :baseline_library_id,
                  :property_id,
                  :current_snapshot,
                  :baseline_snapshot,
                  :entries

      def initialize(
        current_library_id:,
        baseline_library_id:,
        property_id:,
        current_snapshot:,
        baseline_snapshot:,
        entries:
      )
        @current_library_id = current_library_id
        @baseline_library_id = baseline_library_id
        @property_id = property_id
        @current_snapshot = current_snapshot
        @baseline_snapshot = baseline_snapshot
        @entries = Array(entries)
      end

      def current_library
        @current_snapshot.library
      end

      def baseline_library
        @baseline_snapshot.library
      end

      def each(&)
        @entries.each(&)
      end

      def added_entries
        @entries.select(&:added?)
      end

      def removed_entries
        @entries.select(&:removed?)
      end

      def modified_entries
        @entries.select(&:modified?)
      end

      def unchanged_entries
        @entries.select(&:unchanged?)
      end

      def changed_entries
        @entries.reject(&:unchanged?)
      end

      def changeset_documents(include_unchanged: false)
        selected_entries = include_unchanged ? @entries : changed_entries

        selected_entries.each_with_index.map do |entry, index|
          entry.changeset_document(position: index)
        end
      end
    end
  end
end
