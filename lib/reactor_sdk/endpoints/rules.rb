# frozen_string_literal: true

##
# @file endpoints/rules.rb
# @description Endpoint group for Adobe Launch Rule resources.
#
#   Rules define the logic Adobe Launch executes. They consist of
#   conditions (when to run) and actions (what to do). Rules belong
#   to a property and are versioned — the revisions endpoint provides
#   point-in-time snapshots used by the diff engine.
#
# @domain Endpoints
# @see https://developer.adobe.com/experience-platform/documentation/tags/api/endpoints/rules/
#

module ReactorSDK
  module Endpoints
    class Rules < BaseEndpoint
      ##
      # Lists all rules for a given property.
      # Follows pagination automatically — returns all rules.
      #
      # @param property_id [String] Adobe property ID
      # @return [Array<ReactorSDK::Resources::Rule>]
      # @raise [ReactorSDK::ResourceNotFoundError] if the property does not exist
      #
      def list_for_property(property_id)
        records = @paginator.all("/properties/#{property_id}/rules")
        records.map { |r| @parser.parse(r, Resources::Rule) }
      end

      ##
      # Retrieves a single rule by its Adobe ID.
      #
      # @param rule_id [String] Adobe rule ID (format: "RL" + hex string)
      # @return [ReactorSDK::Resources::Rule]
      # @raise [ReactorSDK::ResourceNotFoundError] if the rule does not exist
      #
      def find(rule_id)
        response = @connection.get("/rules/#{rule_id}")
        @parser.parse(response['data'], Resources::Rule)
      end

      ##
      # Creates a new rule within a property.
      #
      # @param property_id [String]  Adobe property ID
      # @param name        [String]  Display name for the rule
      # @param enabled     [Boolean] Whether the rule is enabled (default: true)
      # @return [ReactorSDK::Resources::Rule] The newly created rule
      # @raise [ReactorSDK::UnprocessableEntityError] if attributes are invalid
      #
      def create(property_id:, name:, enabled: true)
        payload  = build_payload('rules', { name: name, enabled: enabled })
        response = @connection.post("/properties/#{property_id}/rules", payload)
        @parser.parse(response['data'], Resources::Rule)
      end

      ##
      # Updates an existing rule.
      #
      # @param rule_id    [String] Adobe rule ID
      # @param attributes [Hash]   Fields to update (e.g. { name: "New Name" })
      # @return [ReactorSDK::Resources::Rule] The updated rule
      # @raise [ReactorSDK::ResourceNotFoundError] if the rule does not exist
      #
      def update(rule_id, attributes)
        payload  = build_payload('rules', attributes, id: rule_id)
        response = @connection.patch("/rules/#{rule_id}", payload)
        @parser.parse(response['data'], Resources::Rule)
      end

      ##
      # Deletes a rule permanently.
      #
      # @param rule_id [String] Adobe rule ID
      # @return [nil]
      # @raise [ReactorSDK::ResourceNotFoundError] if the rule does not exist
      #
      def delete(rule_id)
        @connection.delete("/rules/#{rule_id}")
        nil
      end
    end
  end
end
