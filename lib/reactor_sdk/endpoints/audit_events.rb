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
      # Lists all audit events for a given property.
      # Follows pagination automatically — returns all events.
      #
      # @param property_id [String] Adobe property ID
      # @param since       [String, nil] ISO8601 timestamp — only return events after this time
      # @return [Array<ReactorSDK::Resources::AuditEvent>]
      # @raise [ReactorSDK::ResourceNotFoundError] if the property does not exist
      #
      def list_for_property(property_id, since: nil)
        params  = since ? { 'filter[created_at]' => "GT #{since}" } : {}
        records = @paginator.all("/properties/#{property_id}/audit_events", params: params)
        records.map { |r| @parser.parse(r, Resources::AuditEvent) }
      end

      ##
      # Retrieves a single audit event by its Adobe ID.
      #
      # @param audit_event_id [String] Adobe audit event ID
      # @return [ReactorSDK::Resources::AuditEvent]
      # @raise [ReactorSDK::ResourceNotFoundError] if the event does not exist
      #
      def find(audit_event_id)
        response = @connection.get("/audit_events/#{audit_event_id}")
        @parser.parse(response['data'], Resources::AuditEvent)
      end
    end
  end
end
