# frozen_string_literal: true

##
# @file endpoints/rule_components.rb
# @description Endpoint group for Adobe Launch Rule Component resources.
#
#   Rule components are the individual conditions and actions that make
#   up a rule. Fetching rule components is essential for the diff engine —
#   comparing two versions of a rule's components shows exactly what logic
#   changed between library versions.
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
      # @param rule_component_id [String] Adobe rule component ID (format: "RC" + hex string)
      # @return [ReactorSDK::Resources::RuleComponent]
      # @raise [ReactorSDK::ResourceNotFoundError] if the component does not exist
      #
      def find(rule_component_id)
        response = @connection.get("/rule_components/#{rule_component_id}")
        @parser.parse(response['data'], Resources::RuleComponent)
      end
    end
  end
end
