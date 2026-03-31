# frozen_string_literal: true

##
# @file endpoints/revisions.rb
# @description Endpoint group for Adobe Launch Revision resources.
#
#   The Reactor API exposes revision history in two different shapes:
#
#     1. Resource-scoped revision lists
#        GET /rules/:id/revisions
#        GET /data_elements/:id/revisions
#        GET /extensions/:id/revisions
#        These return versioned resources of the same type as the parent
#        endpoint (Rule, DataElement, Extension), newest first.
#
#     2. Generic revision lookups
#        GET /revisions/:id
#        These are used when another endpoint exposes a dedicated
#        `revisions` resource ID, such as a `latest_revision` relationship.
#
#   In practice this means the list methods below return typed versioned
#   resources, while `find` still resolves an explicit `revisions` ID into
#   a Resources::Revision snapshot wrapper.
#
# @domain Endpoints
# @see https://developer.adobe.com/experience-platform/documentation/tags/api/endpoints/revisions/
#

module ReactorSDK
  module Endpoints
    class Revisions < BaseEndpoint
      ##
      # Retrieves a single generic revision by its Adobe ID.
      #
      # Returns the full revision including the entity snapshot — the complete
      # attributes of the revisioned resource at this point in time. This is
      # the primary method for fetching data needed to build a diff.
      #
      # Calls GET /revisions/:id which returns the revision data alongside
      # the full resource in the included array.
      #
      # Note: this method expects a `revisions` resource ID (for example, an
      # ID surfaced by a `latest_revision` relationship). It does not accept
      # rule, data element, or extension IDs from the resource-scoped
      # `/revisions` list endpoints.
      #
      # @param revision_id [String] Adobe revision ID (format: "RE" + hex string)
      # @return [ReactorSDK::Resources::Revision] Revision with entity_snapshot populated
      # @raise [ReactorSDK::ResourceNotFoundError] if the revision does not exist
      #
      def find(revision_id)
        response = @connection.get("/revisions/#{revision_id}")
        @parser.parse(response['data'], Resources::Revision, response: response)
      end

      ##
      # Lists all revisions for a given rule, newest first.
      #
      # Returns versioned rule resources, newest first.
      # Follows pagination automatically — returns all revisions.
      #
      # @param rule_id [String] Adobe rule ID (format: "RL" + hex string)
      # @return [Array<ReactorSDK::Resources::Rule>] Versioned rules, newest first
      # @raise [ReactorSDK::ResourceNotFoundError] if the rule does not exist
      #
      def list_for_rule(rule_id)
        records = @paginator.all("/rules/#{rule_id}/revisions")
        @parser.parse_many(records, Resources::Rule)
      end

      ##
      # Lists all revisions for a given data element, newest first.
      #
      # Returns versioned data element resources, newest first.
      # Follows pagination automatically — returns all revisions.
      #
      # @param data_element_id [String] Adobe data element ID (format: "DE" + hex string)
      # @return [Array<ReactorSDK::Resources::DataElement>] Versioned data elements, newest first
      # @raise [ReactorSDK::ResourceNotFoundError] if the data element does not exist
      #
      def list_for_data_element(data_element_id)
        records = @paginator.all("/data_elements/#{data_element_id}/revisions")
        @parser.parse_many(records, Resources::DataElement)
      end

      ##
      # Lists all revisions for a given extension, newest first.
      #
      # Returns versioned extension resources, newest first.
      # Follows pagination automatically — returns all revisions.
      #
      # @param extension_id [String] Adobe extension ID (format: "EX" + hex string)
      # @return [Array<ReactorSDK::Resources::Extension>] Versioned extensions, newest first
      # @raise [ReactorSDK::ResourceNotFoundError] if the extension does not exist
      #
      def list_for_extension(extension_id)
        records = @paginator.all("/extensions/#{extension_id}/revisions")
        @parser.parse_many(records, Resources::Extension)
      end
    end
  end
end
