# frozen_string_literal: true

##
# @file response_parser.rb
# @description Transforms raw JSON:API response hashes into typed Ruby objects.
#
#   The Reactor API returns JSON:API format where every resource has:
#     id         — the Adobe resource ID string
#     type       — the resource type (e.g. "rules", "properties")
#     attributes — a hash of the resource's field values
#     meta       — optional metadata hash
#
#   For Revision resources, the response also includes:
#     relationships — identifies the entity this revision belongs to
#     included      — full snapshot of the revisioned resource at this point
#
#   This parser handles both standard resources and the richer Revision
#   response without the caller needing to know the difference.
#
# @domain Infrastructure
#

module ReactorSDK
  class ResponseParser
    ##
    # Parses a single JSON:API resource hash into a typed resource object.
    #
    # For Revision resources, also extracts the included entity snapshot
    # and relationships from the full response envelope if provided.
    #
    # @param data           [Hash]       Raw JSON:API data hash
    # @param resource_class [Class]      Resource class to instantiate
    # @param response       [Hash, nil]  Full response envelope — used to extract
    #                                    included array for Revision resources
    # @return [Object] An instance of resource_class populated with parsed data
    # @raise [ArgumentError] if data is nil
    # @raise [KeyError]      if required JSON:API fields are missing
    #
    def parse(data, resource_class, response: nil)
      raise ArgumentError, 'data cannot be nil' if data.nil?

      base_args = {
        id: data.fetch('id'),
        type: data.fetch('type'),
        attributes: data.fetch('attributes', {}),
        meta: data.fetch('meta', {})
      }

      base_args.merge!(extract_revision_extras(data, response)) if resource_class == Resources::Revision

      resource_class.new(**base_args)
    end

    ##
    # Parses an array of JSON:API resource hashes into typed resource objects.
    # Returns an empty array if data_array is nil or empty.
    #
    # @param data_array     [Array<Hash>] Array of raw JSON:API data hashes
    # @param resource_class [Class]       Resource class to instantiate for each item
    # @param response       [Hash, nil]   Full response envelope (passed through to parse)
    # @return [Array<Object>] Array of resource_class instances
    #
    def parse_many(data_array, resource_class, response: nil)
      Array(data_array).map { |data| parse(data, resource_class, response: response) }
    end

    private

    ##
    # Extracts the included entity snapshot and relationships from a Revision response.
    #
    # When fetching GET /revisions/:id, Adobe returns the full revisioned resource
    # in the `included` array. This method finds the matching included resource
    # and returns it alongside the relationships hash for entity identity extraction.
    #
    # @param data     [Hash]       The revision data object
    # @param response [Hash, nil]  Full response envelope containing included array
    # @return [Hash] Extra keyword args for Revision.new
    #
    def extract_revision_extras(data, response)
      relationships   = data.fetch('relationships', nil)
      included_entity = find_included_entity(data, response)

      {
        relationships: relationships,
        included_entity: included_entity
      }
    end

    ##
    # Finds the included entity resource matching this revision's entity relationship.
    # Returns nil if no included array is present (e.g. list responses).
    #
    # @param data     [Hash]       The revision data object
    # @param response [Hash, nil]  Full response envelope
    # @return [Hash, nil] The matching included resource hash or nil
    #
    def find_included_entity(data, response)
      return nil unless response.is_a?(Hash)

      included = Array(response['included'])
      return nil if included.empty?

      entity_data = data.dig('relationships', 'entity', 'data')
      return nil unless entity_data.is_a?(Hash)

      included.find do |item|
        item['id'] == entity_data['id'] &&
          item['type'] == entity_data['type']
      end
    end
  end
end
