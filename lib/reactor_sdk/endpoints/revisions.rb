# frozen_string_literal: true

##
# @file endpoints/revisions.rb
# @description Endpoint group for Adobe Launch Revision resources.
#
#   Revisions are point-in-time snapshots of revisable resources —
#   rules, data elements, and extensions. Every save creates a new
#   revision capturing the full resource state at that moment.
#
#   Revisions are the foundation of upstream resolution in LaunchGuard.
#   When a resource does not exist in the target library, the app walks
#   upstream (Development → Staging → Production) to find the nearest
#   version, then calls revisions.find to retrieve the full snapshot
#   for comparison.
#
#   Key distinction between list and find:
#     list_for_rule / list_for_data_element / list_for_extension
#       → Returns revision metadata only (id, activity_type, created_at)
#       → Does NOT include the entity snapshot
#       → Use when you need to discover available revision IDs
#
#     find(revision_id)
#       → Returns full revision including the entity snapshot
#       → Use when you need the actual resource attributes at a point in time
#       → Always use this when building a diff
#
# @domain Endpoints
# @see https://developer.adobe.com/experience-platform/documentation/tags/api/endpoints/revisions/
#

module ReactorSDK
  module Endpoints
    class Revisions < BaseEndpoint
      ##
      # Retrieves a single revision by its Adobe ID.
      #
      # Returns the full revision including the entity snapshot — the complete
      # attributes of the revisioned resource at this point in time. This is
      # the primary method for fetching data needed to build a diff.
      #
      # Calls GET /revisions/:id which returns the revision data alongside
      # the full resource in the included array.
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
      # Returns revision metadata only — does NOT include entity snapshots.
      # Use the returned revision IDs with find() when you need full snapshots.
      # Follows pagination automatically — returns all revisions.
      #
      # @param rule_id [String] Adobe rule ID (format: "RL" + hex string)
      # @return [Array<ReactorSDK::Resources::Revision>] All revisions, newest first
      # @raise [ReactorSDK::ResourceNotFoundError] if the rule does not exist
      #
      def list_for_rule(rule_id)
        records = @paginator.all("/rules/#{rule_id}/revisions")
        @parser.parse_many(records, Resources::Revision)
      end

      ##
      # Lists all revisions for a given data element, newest first.
      #
      # Returns revision metadata only — does NOT include entity snapshots.
      # Use the returned revision IDs with find() when you need full snapshots.
      # Follows pagination automatically — returns all revisions.
      #
      # @param data_element_id [String] Adobe data element ID (format: "DE" + hex string)
      # @return [Array<ReactorSDK::Resources::Revision>] All revisions, newest first
      # @raise [ReactorSDK::ResourceNotFoundError] if the data element does not exist
      #
      def list_for_data_element(data_element_id)
        records = @paginator.all("/data_elements/#{data_element_id}/revisions")
        @parser.parse_many(records, Resources::Revision)
      end

      ##
      # Lists all revisions for a given extension, newest first.
      #
      # Returns revision metadata only — does NOT include entity snapshots.
      # Use the returned revision IDs with find() when you need full snapshots.
      # Follows pagination automatically — returns all revisions.
      #
      # @param extension_id [String] Adobe extension ID (format: "EX" + hex string)
      # @return [Array<ReactorSDK::Resources::Revision>] All revisions, newest first
      # @raise [ReactorSDK::ResourceNotFoundError] if the extension does not exist
      #
      def list_for_extension(extension_id)
        records = @paginator.all("/extensions/#{extension_id}/revisions")
        @parser.parse_many(records, Resources::Revision)
      end
    end
  end
end
