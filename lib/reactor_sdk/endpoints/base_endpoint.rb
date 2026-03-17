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
      # @param type       [String]      JSON:API resource type (e.g. "properties")
      # @param attributes [Hash]        Resource attribute values to send
      # @param id         [String, nil] Resource ID — required for PATCH, omit for POST
      # @return [Hash] Correctly structured JSON:API payload
      #
      def build_payload(type, attributes, id: nil)
        data = { type: type, attributes: attributes }
        data[:id] = id if id
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
    end
  end
end
