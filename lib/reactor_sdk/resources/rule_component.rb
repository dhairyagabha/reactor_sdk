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
#   The settings field varies significantly across extension types:
#     - Core custom code actions store JavaScript or HTML in settings["source"]
#     - Adobe Web SDK actions store XDM objects and data objects
#     - Adobe Analytics actions store variable mappings
#     - Third-party extensions define their own settings structure
#
#   Use parsed_settings to access the full settings object as a Ruby Hash.
#   This is the primary accessor for component configuration — it covers
#   all extension types uniformly, exactly as Adobe Launch displays settings
#   in its own version comparison UI.
#
# @domain Resources
# @see https://developer.adobe.com/experience-platform/documentation/tags/api/endpoints/rule-components/
#

module ReactorSDK
  module Resources
    class RuleComponent < BaseResource
      # @return [String] Display name of the rule component
      attribute :name

      # @return [String] Identifies the extension delegate powering this component
      #   Format: "extension-package-name::component-type::component-name"
      #   Example: "core::actions::custom-code"
      #   Example: "adobe-alloy::actions::send-event"
      attribute :delegate_descriptor_id

      # @return [String] Raw settings value exactly as returned by Adobe.
      #   May be a JSON-encoded string or a plain Hash depending on the extension.
      #   Use parsed_settings for reliable Hash access.
      attribute :settings

      # @return [Integer, nil] Execution order of this component within the rule
      attribute :order

      # @return [String] ISO8601 timestamp when the component was created
      attribute :created_at

      # @return [String] ISO8601 timestamp when the component was last updated
      attribute :updated_at

      ##
      # Returns the settings field parsed into a Ruby Hash.
      #
      # This is the primary accessor for component configuration. It handles
      # all extension types uniformly:
      #   - Core custom code (JavaScript, HTML) stored as JSON-encoded string
      #   - Adobe Web SDK XDM objects and data objects
      #   - Adobe Analytics variable mappings and custom setup blocks
      #   - Any third-party extension settings structure
      #
      # The app can render this as formatted JSON for display and diffing —
      # exactly as Adobe Launch does in its own version comparison UI.
      #
      # Behaviour by input type:
      #   - JSON-encoded string → parsed into Hash
      #   - Already a Hash     → returned as-is
      #   - nil or blank       → returns empty Hash
      #   - Unparseable string → returns empty Hash, raw value still on settings
      #
      # The raw settings value is always preserved on the settings attribute
      # unchanged — this method never modifies the underlying data.
      #
      # @return [Hash] Parsed settings or empty hash if nil, blank, or unparseable
      #
      def parsed_settings
        raw = @attributes["settings"]
        return {} if raw.nil? || raw == ""
        return raw if raw.is_a?(Hash)

        JSON.parse(raw)
      rescue JSON::ParserError
        {}
      end

      ##
      # @return [String] Human-readable representation
      #
      def inspect
        "#<ReactorSDK::Resources::RuleComponent " \
          "id=#{id.inspect} " \
          "name=#{name.inspect} " \
          "delegate=#{delegate_descriptor_id.inspect}>"
      end
    end
  end
end
