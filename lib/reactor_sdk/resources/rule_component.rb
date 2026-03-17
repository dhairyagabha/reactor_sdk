# frozen_string_literal: true

##
# @file resources/rule_component.rb
# @description Represents an Adobe Launch Rule Component resource.
#
#   Rule components are the individual conditions and actions that make
#   up a rule. Each component references a delegate (an extension-provided
#   function) via its delegate_descriptor_id and carries a settings hash
#   specific to that delegate.
#
# @domain Resources
# @see https://developer.adobe.com/experience-platform/documentation/tags/api/endpoints/rule-components/
#

module ReactorSDK
  module Resources
    class RuleComponent < BaseResource
      # @return [String] Display name of the rule component
      attribute :name

      # @return [String] Identifies the extension delegate that powers this component
      #   Format: "extension-name::component-type::component-name"
      attribute :delegate_descriptor_id

      # @return [Hash] Configuration settings specific to the delegate
      attribute :settings, default: {}

      # @return [Integer, nil] Execution order within the rule
      attribute :order

      # @return [String] Component type — "trigger", "condition", or "action"
      attribute :rule_order

      # @return [String] ISO8601 timestamp when the component was created
      attribute :created_at

      # @return [String] ISO8601 timestamp when the component was last updated
      attribute :updated_at

      ##
      # @return [String] Human-readable representation
      #
      def inspect
        "#<ReactorSDK::Resources::RuleComponent id=#{id.inspect} name=#{name.inspect} delegate=#{delegate_descriptor_id.inspect}>"
      end
    end
  end
end
