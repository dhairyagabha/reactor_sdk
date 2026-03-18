# frozen_string_literal: true

##
# @file endpoints/extensions.rb
# @description Endpoint group for Adobe Launch Extension resources.
#
#   Extensions provide the delegates (conditions, actions, data element
#   types) available within a property. The Core extension is always
#   present. Third-party extensions such as Adobe Analytics are installed
#   separately. Extension versions are tracked via delegate_descriptor_id.
#
# @domain Endpoints
# @see https://developer.adobe.com/experience-platform/documentation/tags/api/endpoints/extensions/
#

module ReactorSDK
  module Endpoints
    class Extensions < BaseEndpoint
      ##
      # Lists all extensions installed in a given property.
      # Follows pagination automatically — returns all extensions.
      #
      # @param property_id [String] Adobe property ID
      # @return [Array<ReactorSDK::Resources::Extension>]
      # @raise [ReactorSDK::ResourceNotFoundError] if the property does not exist
      #
      def list_for_property(property_id)
        records = @paginator.all("/properties/#{property_id}/extensions")
        records.map { |r| @parser.parse(r, Resources::Extension) }
      end

      ##
      # Retrieves a single extension by its Adobe ID.
      #
      # @param extension_id [String] Adobe extension ID (format: "EX" + hex string)
      # @return [ReactorSDK::Resources::Extension]
      # @raise [ReactorSDK::ResourceNotFoundError] if the extension does not exist
      #
      def find(extension_id)
        response = @connection.get("/extensions/#{extension_id}")
        @parser.parse(response['data'], Resources::Extension)
      end
    end
  end
end
