# frozen_string_literal: true

##
# @file endpoints/extensions.rb
# @description Endpoint group for Adobe Launch Extension resources.
#
#   Extensions provide the delegates (conditions, actions, data element
#   types) available within a property. The Core extension is always
#   present. Third-party extensions are installed separately.
#
#   Important: extensions must be revised before they can be added to
#   a library. Call revise(extension_id) before libraries.add_extensions.
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

      ##
      # Revises an extension so it can be added to a library.
      #
      # Adobe Launch requires every resource to be explicitly revised before
      # it can be added to a library.
      #
      # Always call revise before libraries.add_extensions.
      #
      # @param extension_id [String] Adobe extension ID
      # @return [ReactorSDK::Resources::Extension] The revised extension
      # @raise [ReactorSDK::ResourceNotFoundError] if the extension does not exist
      #
      def revise(extension_id)
        payload = {
          data: {
            id: extension_id,
            type: 'extensions',
            meta: { action: 'revise' }
          }
        }
        response = @connection.patch("/extensions/#{extension_id}", payload)
        @parser.parse(response['data'], Resources::Extension)
      end
    end
  end
end
