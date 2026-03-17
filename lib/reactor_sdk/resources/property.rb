# frozen_string_literal: true

##
# @file resources/property.rb
# @description Represents an Adobe Launch Property resource.
#
#   A Property is the primary container in Adobe Launch. All rules,
#   data elements, extensions, environments, and libraries belong
#   to a property. A company can have many properties.
#
# @domain Resources
# @see https://developer.adobe.com/experience-platform/documentation/tags/api/endpoints/properties/
#

module ReactorSDK
  module Resources
    class Property < BaseResource
      # @return [String] Display name of the property
      attribute :name

      # @return [String] Platform type — one of: "web", "mobile", "edge"
      attribute :platform

      # @return [Boolean] Whether the property is enabled
      attribute :enabled, as: :boolean

      # @return [Array<String>] Domains associated with this property (web only)
      attribute :domains, default: []

      # @return [String] ISO8601 timestamp when the property was created
      attribute :created_at

      # @return [String] ISO8601 timestamp when the property was last updated
      attribute :updated_at

      ##
      # @return [String] Human-readable representation
      #
      def inspect
        "#<ReactorSDK::Resources::Property id=#{id.inspect} name=#{name.inspect} platform=#{platform.inspect}>"
      end
    end
  end
end
