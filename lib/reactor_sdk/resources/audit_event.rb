# frozen_string_literal: true

##
# @file resources/audit_event.rb
# @description Represents an Adobe Launch Audit Event resource.
#
#   Audit events record every significant action taken within Adobe Launch —
#   creates, updates, deletes, publishes, and state transitions.
#   LaunchGuard syncs these events into its own audit log to provide a
#   complete cross-platform activity record.
#
# @domain Resources
# @see https://developer.adobe.com/experience-platform/documentation/tags/api/endpoints/audit-events/
#

module ReactorSDK
  module Resources
    class AuditEvent < BaseResource
      # @return [String] The type of action that occurred
      attribute :type_of

      # @return [String] Human-readable name of the affected resource
      attribute :entity_display_name

      # @return [String] ISO8601 timestamp when the event occurred
      attribute :created_at

      # @return [Hash, nil] Snapshot of the resource before the action
      attribute :previous_attributes

      # @return [Hash, nil] Snapshot of the resource after the action
      attribute :updated_attributes

      ##
      # @return [String] Human-readable representation
      #
      def inspect
        '#<ReactorSDK::Resources::AuditEvent ' \
          "id=#{id.inspect} " \
          "type=#{type_of.inspect} " \
          "entity=#{entity_display_name.inspect}>"
      end
    end
  end
end
