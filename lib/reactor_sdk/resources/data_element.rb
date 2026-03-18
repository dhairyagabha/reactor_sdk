# frozen_string_literal: true

##
# @file resources/data_element.rb
# @description Represents an Adobe Launch Data Element resource.
#
#   Data elements are the building blocks of Adobe Launch's data layer.
#   They define reusable values that can be referenced in rules and other
#   data elements. Each data element is powered by an extension delegate.
#
#   The settings field varies across extension types:
#     - Core custom code data elements store JavaScript in settings["source"]
#     - Other extensions define their own settings structure
#
#   Use parsed_settings to access the full settings object as a Ruby Hash.
#   This is the primary accessor for data element configuration — it covers
#   all extension types uniformly, exactly as Adobe Launch displays settings
#   in its own version comparison UI.
#
# @domain Resources
# @see https://developer.adobe.com/experience-platform/documentation/tags/api/endpoints/data-elements/
#

module ReactorSDK
  module Resources
    class DataElement < BaseResource
      # @return [String] Display name of the data element
      attribute :name

      # @return [Boolean] Whether the data element is enabled
      attribute :enabled, as: :boolean

      # @return [Boolean] Whether to clean text values
      attribute :clean_text, as: :boolean

      # @return [Boolean] Whether to force lowercase
      attribute :force_lower_case, as: :boolean

      # @return [String, nil] Default value when the element returns nil
      attribute :default_value

      # @return [String, nil] How long to cache the value
      #   One of: "none", "pageview", "session", "visitor", or seconds as string
      attribute :storage_duration

      # @return [String] Identifies the extension delegate powering this element
      #   Format: "extension-package-name::data-element::element-name"
      #   Example: "core::dataElements::custom-code"
      attribute :delegate_descriptor_id

      # @return [String] Raw settings value exactly as returned by Adobe.
      #   May be a JSON-encoded string or a plain Hash depending on the extension.
      #   Use parsed_settings for reliable Hash access.
      attribute :settings

      # @return [String] ISO8601 timestamp when the element was created
      attribute :created_at

      # @return [String] ISO8601 timestamp when the element was last updated
      attribute :updated_at

      # @return [String, nil] ISO8601 timestamp when the element was last published
      attribute :published_at

      ##
      # Returns the settings field parsed into a Ruby Hash.
      #
      # This is the primary accessor for data element configuration. It handles
      # all extension types uniformly:
      #   - Core custom code elements storing JavaScript as JSON-encoded string
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
        raw = @attributes['settings']
        return {} if raw.nil? || raw == ''
        return raw if raw.is_a?(Hash)

        JSON.parse(raw)
      rescue JSON::ParserError
        {}
      end

      ##
      # @return [String] Human-readable representation
      #
      def inspect
        '#<ReactorSDK::Resources::DataElement ' \
          "id=#{id.inspect} " \
          "name=#{name.inspect} " \
          "delegate=#{delegate_descriptor_id.inspect}>"
      end
    end
  end
end
