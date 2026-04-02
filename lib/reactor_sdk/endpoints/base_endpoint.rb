# frozen_string_literal: true

##
# @file endpoints/base_endpoint.rb
# @description Base class for all Reactor API endpoint groups.
#
#   Provides three shared dependencies to every endpoint subclass:
#     - connection   for making authenticated HTTP calls
#     - paginator    for fetching all pages of list endpoints
#     - parser       for converting JSON:API hashes into typed resources
#
#   Also provides two protected helper methods used by every endpoint:
#     - build_payload            builds a JSON:API write payload (POST/PATCH)
#     - build_relationship_payload builds a JSON:API relationship payload
#
#   Every endpoint class inherits from this and focuses only on its
#   own resource domain — it never touches HTTP or pagination directly.
#
# @domain Endpoints
#

module ReactorSDK
  module Endpoints
    class BaseEndpoint
      ##
      # @param connection [ReactorSDK::Connection]      Authenticated HTTP client
      # @param paginator  [ReactorSDK::Paginator]       Handles cursor pagination
      # @param parser     [ReactorSDK::ResponseParser]  Converts JSON:API to resources
      #
      def initialize(connection:, paginator:, parser:)
        @connection = connection
        @paginator  = paginator
        @parser     = parser
      end

      protected

      ##
      # Builds a JSON:API compliant request payload for create and update requests.
      #
      # POST (create) — omit the id parameter:
      #   build_payload("properties", { name: "My Site", platform: "web" })
      #   => { data: { type: "properties", attributes: { name: "My Site", platform: "web" } } }
      #
      # PATCH (update) — include the id parameter:
      #   build_payload("properties", { name: "New Name" }, id: "PR123")
      #   => { data: { id: "PR123", type: "properties", attributes: { name: "New Name" } } }
      #
      # @param type          [String]      JSON:API resource type (e.g. "properties")
      # @param attributes    [Hash]        Resource attribute values to send
      # @param id            [String, nil] Resource ID — required for PATCH, omit for POST
      # @param relationships [Hash, nil]   JSON:API relationships payload
      # @param meta          [Hash, nil]   JSON:API meta payload
      # @return [Hash] Correctly structured JSON:API payload
      #
      def build_payload(type, attributes, id: nil, relationships: nil, meta: nil)
        data = { type: type, attributes: attributes }
        data[:id] = id if id
        data[:relationships] = relationships if relationships
        data[:meta] = meta if meta
        { data: data }
      end

      ##
      # Builds a JSON:API relationship payload for associating resources.
      # Used when adding rules, data elements, or extensions to a library.
      #
      # @example Add two rules to a library
      #   build_relationship_payload("rules", ["RL123", "RL456"])
      #   => { data: [{ id: "RL123", type: "rules" }, { id: "RL456", type: "rules" }] }
      #
      # @param type [String]        JSON:API resource type
      # @param ids  [Array<String>] Array of Adobe resource IDs to associate
      # @return [Hash] JSON:API relationship payload
      #
      def build_relationship_payload(type, ids)
        {
          data: Array(ids).map { |id| { id: id, type: type } }
        }
      end

      ##
      # Fetches and parses a single related resource.
      #
      # @param path           [String]
      # @param resource_class [Class]
      # @param params         [Hash]
      # @return [Object]
      #
      def fetch_resource(path, resource_class, params: {})
        response = @connection.get(path, params: params)
        @parser.parse(response['data'], resource_class, response: response)
      end

      ##
      # Fetches and parses a related resource collection.
      #
      # @param path           [String]
      # @param resource_class [Class]
      # @param params         [Hash]
      # @return [Array<Object>]
      #
      def list_resources(path, resource_class, params: {})
        records = @paginator.all(path, params: params)
        @parser.parse_many(records, resource_class)
      end

      ##
      # Fetches and parses a heterogeneous resource collection using
      # each record's JSON:API type to choose the SDK class.
      #
      # @param path [String]
      # @param params [Hash]
      # @return [Array<ReactorSDK::Resources::BaseResource>]
      #
      def list_resources_auto(path, params: {})
        records = @paginator.all(path, params: params)
        @parser.parse_many_auto(records)
      end

      ##
      # Creates and parses a single resource.
      #
      # @param path           [String]
      # @param type           [String]
      # @param resource_class [Class]
      # @param attributes     [Hash]
      # @param relationships  [Hash, nil]
      # @param meta           [Hash, nil]
      # @return [Object]
      #
      def create_resource(path, type, resource_class, attributes:, relationships: nil, meta: nil)
        payload = build_payload(type, attributes, relationships: relationships, meta: meta)
        response = @connection.post(path, payload)
        @parser.parse(response['data'], resource_class, response: response)
      end

      ##
      # Updates and parses a single resource.
      #
      # @param path           [String]
      # @param id             [String]
      # @param type           [String]
      # @param resource_class [Class]
      # @param attributes     [Hash]
      # @param relationships  [Hash, nil]
      # @param meta           [Hash, nil]
      # @return [Object]
      #
      def update_resource(path, id, type, resource_class, attributes:, relationships: nil, meta: nil)
        payload = build_payload(
          type,
          attributes,
          id: id,
          relationships: relationships,
          meta: meta
        )
        response = @connection.patch(path, payload)
        @parser.parse(response['data'], resource_class, response: response)
      end

      ##
      # Deletes a resource and normalizes the nil return value.
      #
      # @param path [String]
      # @return [nil]
      #
      def delete_resource(path)
        @connection.delete(path)
        nil
      end

      ##
      # Fetches raw relationship linkage data.
      #
      # @param path   [String]
      # @param params [Hash]
      # @return [Hash, Array<Hash>, nil]
      #
      def fetch_relationship(path, params: {})
        response = @connection.get(path, params: params)
        response['data']
      end

      ##
      # Creates a note under a notable resource.
      #
      # @param path [String]
      # @param text [String]
      # @return [ReactorSDK::Resources::Note]
      #
      def create_note_for_path(path, text)
        create_resource(path, 'notes', Resources::Note, attributes: { text: text })
      end

      ##
      # Lists note resources for a notable resource path.
      #
      # @param path [String]
      # @return [Array<ReactorSDK::Resources::Note>]
      #
      def list_notes_for_path(path)
        list_resources(path, Resources::Note)
      end
    end
  end
end
