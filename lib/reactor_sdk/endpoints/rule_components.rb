# frozen_string_literal: true

##
# @file endpoints/rule_components.rb
# @description Endpoint group for Adobe Launch Rule Component resources.
#
#   Rule components are the individual conditions and actions that make
#   up a rule. Each component references an extension delegate via
#   delegate_descriptor_id and carries a settings hash specific to
#   that delegate.
#
#   Creating a rule component:
#     - Endpoint: POST /properties/:property_id/rule_components
#     - The rule relationship is passed in the payload, not the URL
#     - Requires extension relationship in the payload
#     - settings must be a JSON-encoded string
#
# @domain Endpoints
# @see https://developer.adobe.com/experience-platform/documentation/tags/api/endpoints/rule-components/
#

module ReactorSDK
  module Endpoints
    class RuleComponents < BaseEndpoint
      ##
      # Lists all components for a given rule.
      # Follows pagination automatically — returns all components.
      #
      # @param rule_id [String] Adobe rule ID
      # @return [Array<ReactorSDK::Resources::RuleComponent>]
      # @raise [ReactorSDK::ResourceNotFoundError] if the rule does not exist
      #
      def list_for_rule(rule_id)
        records = @paginator.all("/rules/#{rule_id}/rule_components")
        records.map { |r| @parser.parse(r, Resources::RuleComponent) }
      end

      ##
      # Retrieves a single rule component by its Adobe ID.
      #
      # @param rule_component_id [String] Adobe rule component ID (format: "RC" + hex)
      # @return [ReactorSDK::Resources::RuleComponent]
      # @raise [ReactorSDK::ResourceNotFoundError] if the component does not exist
      #
      def find(rule_component_id)
        response = @connection.get("/rule_components/#{rule_component_id}")
        @parser.parse(response['data'], Resources::RuleComponent)
      end

      ##
      # Creates a new rule component on a property.
      #
      # The component is associated with a rule via the relationships.rules
      # payload — NOT via the URL. The endpoint is always
      # POST /properties/:property_id/rule_components.
      #
      # The delegate_descriptor_id identifies which extension capability
      # powers this component. Examples:
      #   "core::actions::custom-code"         — Core custom code action
      #   "core::conditions::value-comparison"  — Core value comparison condition
      #   "core::events::click"                 — Core click event
      #
      # The settings field must be a JSON-encoded string matching the schema
      # expected by the delegate. For Core custom code:
      #   settings: JSON.generate({ source: "console.log('hi');", language: "javascript" })
      #
      # @param property_id            [String]  Adobe property ID
      # @param rule_id                [String]  Adobe rule ID to attach the component to
      # @param name                   [String]  Display name
      # @param delegate_descriptor_id [String]  Extension delegate identifier
      # @param settings               [String]  JSON-encoded settings string
      # @param extension_id           [String]  Adobe extension ID providing the delegate
      # @param rule_order             [Float]   Execution order within the rule (default: 50.0)
      # @param order                  [Integer] Order within same-type components (default: 0)
      # @return [ReactorSDK::Resources::RuleComponent]
      # @raise [ReactorSDK::UnprocessableEntityError] if attributes are invalid
      #
      def create(
        property_id:,
        rule_id:,
        name:,
        delegate_descriptor_id:,
        settings:,
        extension_id:,
        rule_order: 50.0,
        order:      0
      )
        payload = build_rule_component_payload(
          name, delegate_descriptor_id, settings,
          extension_id, rule_id, rule_order, order
        )
        response = @connection.post(
          "/properties/#{property_id}/rule_components",
          payload
        )
        @parser.parse(response['data'], Resources::RuleComponent)
      end

      ##
      # Updates an existing rule component.
      #
      # @param rule_component_id [String] Adobe rule component ID
      # @param attributes        [Hash]   Fields to update
      # @return [ReactorSDK::Resources::RuleComponent]
      # @raise [ReactorSDK::ResourceNotFoundError] if the component does not exist
      #
      def update(rule_component_id, attributes)
        payload  = build_payload('rule_components', attributes, id: rule_component_id)
        response = @connection.patch("/rule_components/#{rule_component_id}", payload)
        @parser.parse(response['data'], Resources::RuleComponent)
      end

      ##
      # Deletes a rule component permanently.
      #
      # @param rule_component_id [String] Adobe rule component ID
      # @return [nil]
      # @raise [ReactorSDK::ResourceNotFoundError] if the component does not exist
      #
      def delete(rule_component_id)
        @connection.delete("/rule_components/#{rule_component_id}")
        nil
      end

      private

      ##
      # Builds the JSON:API payload for rule component creation.
      # Includes both extension and rules relationships.
      #
      # @param name                   [String]  Display name
      # @param delegate_descriptor_id [String]  Delegate identifier
      # @param settings               [String]  JSON-encoded settings
      # @param extension_id           [String]  Extension providing the delegate
      # @param rule_id                [String]  Rule to attach this component to
      # @param rule_order             [Float]   Rule execution order
      # @param order                  [Integer] Component order within type
      # @return [Hash] JSON:API compliant payload
      #
      def build_rule_component_payload(
        name, delegate_descriptor_id, settings,
        extension_id, rule_id, rule_order, order
      )
        {
          data: {
            type: 'rule_components',
            attributes: {
              name: name,
              delegate_descriptor_id: delegate_descriptor_id,
              settings: settings,
              rule_order: rule_order,
              order: order
            },
            relationships: {
              extension: {
                data: { id: extension_id, type: 'extensions' }
              },
              rules: {
                data: [{ id: rule_id, type: 'rules' }]
              }
            }
          }
        }
      end
    end
  end
end
