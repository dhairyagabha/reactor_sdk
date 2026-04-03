# frozen_string_literal: true

##
# @file resources/library_with_resources.rb
# @description A richer Library resource returned by Libraries#find_with_resources.
#
#   When fetching GET /libraries/:id?include=rules,data_elements,extensions
#   Adobe returns the library alongside all its associated resources in the
#   JSON:API included array. Each included resource carries a relationships
#   hash containing its current revision ID.
#
#   This class wraps that response and exposes:
#     - All standard Library attributes (name, state, etc.)
#     - rules          — Array of Rule resources with revision_id attached
#     - data_elements  — Array of DataElement resources with revision_id attached
#     - extensions     — Array of Extension resources with revision_id attached
#
#   The revision_id on each resource is the key the app uses for upstream
#   resolution — when a resource does not exist in the target library, the
#   app walks upstream (Development → Staging → Production) to find the
#   nearest version and fetches that revision for comparison.
#
#   This class is never instantiated directly — always created via
#   Libraries#find_with_resources which passes the full API response.
#
# @domain Resources
# @see https://developer.adobe.com/experience-platform/documentation/tags/api/endpoints/libraries/
#

module ReactorSDK
  module Resources
    class LibraryWithResources < BaseResource
      # @return [String] Display name of the library
      attribute :name

      # @return [String] Current workflow state
      #   One of: "development", "submitted", "approved", "rejected", "published"
      attribute :state

      # @return [Boolean] Whether the library has been published
      attribute :published, as: :boolean

      # @return [String] ISO8601 timestamp when the library was created
      attribute :created_at

      # @return [String] ISO8601 timestamp when the library was last updated
      attribute :updated_at

      # @return [String, nil] ISO8601 timestamp when the library was published
      attribute :published_at

      # @return [Array<ReactorSDK::Resources::Rule>] Rules in this library
      #   Each rule has a revision_id attribute attached from the relationship data
      attr_reader :rules

      # @return [Array<ReactorSDK::Resources::DataElement>] Data elements in this library
      #   Each data element has a revision_id attribute attached
      attr_reader :data_elements

      # @return [Array<ReactorSDK::Resources::Extension>] Extensions in this library
      #   Each extension has a revision_id attribute attached
      attr_reader :extensions

      ##
      # Initializes the library with its included resources.
      #
      # Accepts the standard BaseResource arguments plus an included_resources
      # hash that maps resource type to arrays of raw JSON:API resource hashes
      # extracted from the API response included array.
      #
      # @param id                [String] Adobe library ID
      # @param type              [String] JSON:API type ("libraries")
      # @param attributes        [Hash]   Library attribute values
      # @param meta              [Hash]   Optional metadata
      # @param included_resources [Hash]  Keyed by type — raw included resource arrays
      #   {
      #     "rules"         => [ { "id" => "RL123", "type" => "rules",
      #                            "attributes" => {...},
      #                            "relationships" => { "latest_revision" => { "data" => { "id" => "RE123" } } } } ],
      #     "data_elements" => [ ... ],
      #     "extensions"    => [ ... ]
      #   }
      #
      def initialize(
        id:,
        type:,
        attributes:          {},
        meta:                {},
        included_resources:  {}
      )
        super(id: id, type: type, attributes: attributes, meta: meta)
        @rules         = build_resources(included_resources['rules'],         Resources::Rule)
        @data_elements = build_resources(included_resources['data_elements'], Resources::DataElement)
        @extensions    = build_resources(included_resources['extensions'],    Resources::Extension)
      end

      ##
      # Returns true if the library is in a state where it can be built.
      #
      # @return [Boolean]
      #
      def buildable?
        state == 'development'
      end

      ##
      # Returns true if the library has been successfully published.
      #
      # @return [Boolean]
      #
      def published?
        state == 'published'
      end

      ##
      # Returns a flat index of all resources keyed by Adobe resource ID.
      # Maps each resource ID to its current revision ID.
      # Covers rules, data elements, and extensions in a single lookup.
      #
      # Used by the app to compare two libraries — call resource_index on
      # both the source and target library, then compare revision IDs to
      # find what changed, what was added, and what needs upstream resolution.
      #
      # @return [Hash] { "RL123" => "RE456", "DE789" => "RE012", ... }
      #
      def resource_index
        (@rules + @data_elements + @extensions).each_with_object({}) do |resource, index|
          index[resource.id] = resource.revision_id if resource.revision_id
        end
      end

      ##
      # Returns all included resources as a flat array regardless of type.
      #
      # @return [Array<BaseResource>]
      #
      def all_resources
        @rules + @data_elements + @extensions
      end

      ##
      # @return [String] Human-readable representation
      #
      def inspect
        '#<ReactorSDK::Resources::LibraryWithResources ' \
          "id=#{id.inspect} " \
          "name=#{name.inspect} " \
          "state=#{state.inspect} " \
          "rules=#{@rules.length} " \
          "data_elements=#{@data_elements.length} " \
          "extensions=#{@extensions.length}>"
      end

      private

      ##
      # Builds an array of typed resource objects from raw included resource hashes.
      # Attaches revision_id to each resource extracted from its relationships.
      #
      # @param raw_resources  [Array<Hash>, nil] Raw JSON:API resource hashes
      # @param resource_class [Class]             Resource class to instantiate
      # @return [Array<BaseResource>] Typed resource objects with revision_id attached
      #
      def build_resources(raw_resources, resource_class)
        Array(raw_resources).map do |raw|
          resource = resource_class.new(
            id: raw.fetch('id'),
            type: raw.fetch('type'),
            attributes: raw.fetch('attributes', {}),
            meta: raw.fetch('meta', {}),
            relationships: raw.fetch('relationships', {})
          )
          resource.instance_variable_set(
            :@revision_id,
            extract_revision_id(raw)
          )
          resource.singleton_class.attr_reader :revision_id
          resource
        end
      end

      ##
      # Extracts the latest revision ID from a resource's relationships hash.
      # Adobe stores it under relationships.latest_revision.data.id.
      #
      # @param raw [Hash] Raw JSON:API resource hash
      # @return [String, nil] Revision ID or nil if not present
      #
      def extract_revision_id(raw)
        raw.dig('relationships', 'latest_revision', 'data', 'id')
      end
    end
  end
end
