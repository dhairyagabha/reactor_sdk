# frozen_string_literal: true

##
# @file resources/revision.rb
# @description Represents an Adobe Launch Revision resource.
#
#   Revisions are point-in-time snapshots of any revisable resource —
#   rules, data elements, and extensions. Every time a revisable resource
#   is saved, Adobe creates a new revision capturing its full state at
#   that moment.
#
#   Revisions are the foundation of LaunchGuard's diff engine. By fetching
#   the revision from each library and comparing the two snapshots, the
#   exact field-level changes between versions can be determined.
#
#   The full resource snapshot is returned in the JSON:API `included`
#   array when fetching a revision with `GET /revisions/:id`. This class
#   extracts that snapshot and exposes it alongside the revision metadata.
#
#   Upstream resolution: when a resource does not exist in the target
#   library, the app walks upstream through the environment chain
#   (Development → Staging → Production) to find the nearest version
#   to diff against. The SDK provides the data — the app owns this logic.
#
# @domain Resources
# @see https://developer.adobe.com/experience-platform/documentation/tags/api/endpoints/revisions/
#

module ReactorSDK
  module Resources
    class Revision < BaseResource
      # @return [String] ISO8601 timestamp when this revision was created
      attribute :created_at

      # @return [String, nil] The action that triggered this revision
      #   Common values: "created", "updated", "published", "rejected"
      attribute :activity_type

      ##
      # Returns the full attributes snapshot of the resource at this revision.
      #
      # Adobe returns the revisioned resource in the JSON:API `included` array
      # when fetching a revision. This method extracts those attributes so the
      # app can compare two snapshots field by field.
      #
      # Returns an empty Hash if the included snapshot is not present —
      # this happens when fetching a revision list (GET /rules/:id/revisions)
      # rather than a single revision (GET /revisions/:id). Always use
      # revisions.find(id) when you need the full snapshot.
      #
      # @return [Hash] Full attributes of the revisioned resource, or {} if absent
      #
      def entity_snapshot
        return {} if @included_entity.nil?

        @included_entity.fetch('attributes', {})
      end

      ##
      # Returns the full relationships snapshot of the resource at this revision.
      #
      # @return [Hash]
      #
      def entity_relationships
        return {} if @included_entity.nil?

        @included_entity.fetch('relationships', {})
      end

      ##
      # Returns the Adobe ID of the resource this revision belongs to.
      # Extracted from the JSON:API relationships on the revision.
      #
      # @return [String, nil] Resource ID (e.g. "RL123") or nil if not present
      #
      attr_reader :entity_id

      ##
      # Returns the JSON:API type of the resource this revision belongs to.
      # Extracted from the JSON:API relationships on the revision.
      #
      # @return [String, nil] Resource type (e.g. "rules") or nil if not present
      #
      attr_reader :entity_type

      ##
      # Overrides BaseResource initializer to extract the included entity
      # and relationship data from the raw JSON:API response.
      #
      # In addition to standard id/type/attributes/meta, the Revision resource
      # accepts two extra keyword arguments:
      #   - included_entity: the raw included resource hash from the API response
      #   - relationships:   the relationships hash from the revision data object
      #
      # These are passed by the ResponseParser when building a Revision from
      # a full GET /revisions/:id response.
      #
      # @param id               [String] Adobe revision ID
      # @param type             [String] JSON:API type ("revisions")
      # @param attributes       [Hash]   Revision attributes
      # @param meta             [Hash]   Optional metadata
      # @param included_entity  [Hash, nil] Raw included resource from API response
      # @param relationships    [Hash, nil] Relationships hash from the revision
      #
      def initialize(
        id:,
        type:,
        attributes:      {},
        meta:            {},
        relationships:   {},
        included_entity: nil,
        revision_relationships: nil
      )
        super(
          id: id,
          type: type,
          attributes: attributes,
          meta: meta,
          relationships: relationships
        )
        @included_entity = included_entity
        extract_entity_identity(revision_relationships || relationships)
      end

      ##
      # @return [String] Human-readable representation
      #
      def inspect
        '#<ReactorSDK::Resources::Revision ' \
          "id=#{id.inspect} " \
          "activity_type=#{activity_type.inspect} " \
          "entity_id=#{entity_id.inspect} " \
          "entity_type=#{entity_type.inspect}>"
      end

      private

      ##
      # Extracts the entity ID and type from the revision's relationships hash.
      # Adobe stores the revisioned resource reference under relationships.entity.data.
      #
      # @param relationships [Hash, nil] The relationships object from the API response
      # @sideeffect Sets @entity_id and @entity_type
      #
      def extract_entity_identity(relationships)
        return unless relationships.is_a?(Hash)

        entity_data = relationships.dig('entity', 'data')
        return unless entity_data.is_a?(Hash)

        @entity_id   = entity_data['id']
        @entity_type = entity_data['type']
      end
    end
  end
end
