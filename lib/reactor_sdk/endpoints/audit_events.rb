# frozen_string_literal: true

##
# @file endpoints/audit_events.rb
# @description Endpoint group for Adobe Launch Audit Event resources.
#
#   Audit events record every significant action taken within Adobe Launch —
#   creates, updates, deletes, publishes, and state transitions.
#   LaunchGuard syncs these events into its own audit log to provide a
#   complete cross-platform activity record.
#
# @domain Endpoints
# @see https://developer.adobe.com/experience-platform/documentation/tags/api/endpoints/audit-events/
#

module ReactorSDK
  module Endpoints
    class AuditEvents < BaseEndpoint
      ##
      # Lists audit events from Adobe's current global audit events endpoint.
      # Follows pagination automatically — returns all events.
      #
      # @param since      [String, nil] ISO8601 timestamp — only return events after this time
      # @param updated_at [String, nil] Optional updated_at filter
      # @param type_of    [String, nil] Optional event type filter
      # @return [Array<ReactorSDK::Resources::AuditEvent>]
      #
      def list(since: nil, updated_at: nil, type_of: nil)
        params = {}
        params['created_at'] = "GT #{since}" if since
        params['updated_at'] = updated_at if updated_at
        params['type_of'] = type_of if type_of

        list_resources('/audit_events', Resources::AuditEvent, params: params)
      end

      ##
      # Backward-compatible wrapper for older SDK integrations.
      #
      # Adobe's current official Reactor OpenAPI documents only the global
      # `/audit_events` listing endpoint, so property scoping is no longer
      # performed through the request path.
      #
      # @param _property_id [String]
      # @param since [String, nil]
      # @return [Array<ReactorSDK::Resources::AuditEvent>]
      #
      def list_for_property(_property_id, since: nil)
        list(since: since)
      end

      ##
      # Retrieves a single audit event by its Adobe ID.
      #
      # @param audit_event_id [String] Adobe audit event ID
      # @return [ReactorSDK::Resources::AuditEvent]
      # @raise [ReactorSDK::ResourceNotFoundError] if the event does not exist
      #
      def find(audit_event_id)
        fetch_resource("/audit_events/#{audit_event_id}", Resources::AuditEvent)
      end
    end
  end
end
