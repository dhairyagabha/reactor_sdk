# frozen_string_literal: true

##
# @file resources/extension.rb
# @description Represents an Adobe Launch Extension resource.
#
#   Extensions are packages that provide delegates (conditions, actions,
#   data element types) to a property. The Core extension is installed
#   by default. Third-party extensions (Adobe Analytics, etc.) are
#   installed separately. The delegate_descriptor_id includes the
#   extension name and version.
#
# @domain Resources
# @see https://developer.adobe.com/experience-platform/documentation/tags/api/endpoints/extensions/
#

module ReactorSDK
  module Resources
    class Extension < BaseResource
      # @return [String] Identifies the extension package and version
      #   Format: "extension-package-name::extensionName::version"
      attribute :delegate_descriptor_id

      # @return [String] Display name of the extension
      attribute :name

      # @return [Boolean] Whether this is the always-present Core extension
      attribute :created_at

      # @return [Hash] Extension-level configuration settings
      attribute :settings, default: {}

      # @return [String] ISO8601 timestamp when the extension was installed
      attribute :created_at

      # @return [String] ISO8601 timestamp when the extension was last updated
      attribute :updated_at

      # @return [String, nil] ISO8601 timestamp when the extension was last published
      attribute :published_at

      ##
      # @return [String] Human-readable representation
      #
      def inspect
        "#<ReactorSDK::Resources::Extension id=#{id.inspect} delegate=#{delegate_descriptor_id.inspect}>"
      end
    end
  end
end
