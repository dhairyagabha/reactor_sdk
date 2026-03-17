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
#   This parser extracts those fields and passes them to a resource class
#   to construct a clean, typed Ruby object.
#
#   Used by every endpoint class to convert raw API responses.
#   Never called directly by application code.
#
# @domain Infrastructure
#

module ReactorSDK
  class ResponseParser
    ##
    # Parses a single JSON:API resource hash into a typed resource object.
    #
    # @param data           [Hash]  Raw JSON:API data hash containing id, type, attributes
    # @param resource_class [Class] Resource class to instantiate (e.g. Resources::Property)
    # @return [Object] An instance of resource_class populated with the parsed data
    # @raise [ArgumentError] if data is nil
    # @raise [KeyError]      if required JSON:API fields are missing
    #
    def parse(data, resource_class)
      raise ArgumentError, "data cannot be nil" if data.nil?

      resource_class.new(
        id:         data.fetch("id"),
        type:       data.fetch("type"),
        attributes: data.fetch("attributes", {}),
        meta:       data.fetch("meta", {})
      )
    end

    ##
    # Parses an array of JSON:API resource hashes into typed resource objects.
    # Returns an empty array if data_array is nil or empty.
    #
    # @param data_array     [Array<Hash>] Array of raw JSON:API data hashes
    # @param resource_class [Class]       Resource class to instantiate for each item
    # @return [Array<Object>] Array of resource_class instances
    #
    def parse_many(data_array, resource_class)
      Array(data_array).map { |data| parse(data, resource_class) }
    end
  end
end
