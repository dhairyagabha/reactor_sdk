# frozen_string_literal: true

##
# @file resources/extension.rb
# @description Represents an Adobe Launch Extension resource.
#
#   Extensions provide the delegates (conditions, actions, data element
#   types) available within a property. The Core extension is always
#   present. Third-party extensions such as Adobe Analytics are installed
#   separately. Extension versions are tracked via delegate_descriptor_id.
#
# @domain Resources
# @see https://developer.adobe.com/experience-platform/documentation/tags/api/endpoints/extensions/
#

module ReactorSDK
  module Resources
    class Extension < BaseResource
      # @return [String] Identifies the extension package and version
      attribute :delegate_descriptor_id

      # @return [String] Display name of the extension
      attribute :name

      # @return [String] Raw settings value exactly as returned by Adobe
      attribute :settings

      # @return [String] ISO8601 timestamp when the extension was installed
      attribute :created_at

      # @return [String] ISO8601 timestamp when the extension was last updated
      attribute :updated_at

      # @return [String, nil] ISO8601 timestamp when the extension was published
      attribute :published_at

      ##
      # Returns the settings field parsed into a Ruby Hash.
      #
      # Extension-level settings vary by extension type. Use this for
      # display and diffing — exactly as Adobe Launch does in its own
      # version comparison UI.
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
        '#<ReactorSDK::Resources::Extension ' \
          "id=#{id.inspect} " \
          "delegate=#{delegate_descriptor_id.inspect}>"
      end
    end
  end
end
