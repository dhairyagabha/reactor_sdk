# frozen_string_literal: true

##
# @file endpoints/data_elements.rb
# @description Endpoint group for Adobe Launch Data Element resources.
#
#   Data elements are reusable values that can be referenced throughout
#   rules and other data elements. They form the data layer of Adobe Launch.
#
# @domain Endpoints
# @see https://developer.adobe.com/experience-platform/documentation/tags/api/endpoints/data-elements/
#

module ReactorSDK
  module Endpoints
    class DataElements < BaseEndpoint
      ##
      # Lists all data elements for a given property.
      # Follows pagination automatically — returns all data elements.
      #
      # @param property_id [String] Adobe property ID
      # @return [Array<ReactorSDK::Resources::DataElement>]
      # @raise [ReactorSDK::ResourceNotFoundError] if the property does not exist
      #
      def list_for_property(property_id)
        records = @paginator.all("/properties/#{property_id}/data_elements")
        records.map { |r| @parser.parse(r, Resources::DataElement) }
      end

      ##
      # Retrieves a single data element by its Adobe ID.
      #
      # @param data_element_id [String] Adobe data element ID (format: "DE" + hex string)
      # @return [ReactorSDK::Resources::DataElement]
      # @raise [ReactorSDK::ResourceNotFoundError] if the data element does not exist
      #
      def find(data_element_id)
        response = @connection.get("/data_elements/#{data_element_id}")
        @parser.parse(response['data'], Resources::DataElement)
      end

      ##
      # Creates a new data element within a property.
      #
      # @param property_id           [String]  Adobe property ID
      # @param name                  [String]  Display name
      # @param delegate_descriptor_id [String] Extension delegate identifier
      # @param settings              [Hash]    Delegate-specific configuration
      # @param enabled               [Boolean] Whether the element is enabled
      # @return [ReactorSDK::Resources::DataElement] The newly created data element
      # @raise [ReactorSDK::UnprocessableEntityError] if attributes are invalid
      #
      def create(property_id:, name:, delegate_descriptor_id:, settings: {}, enabled: true)
        payload = build_payload(
          'data_elements',
          {
            name: name,
            delegate_descriptor_id: delegate_descriptor_id,
            settings: settings,
            enabled: enabled
          }
        )
        response = @connection.post("/properties/#{property_id}/data_elements", payload)
        @parser.parse(response['data'], Resources::DataElement)
      end

      ##
      # Updates an existing data element.
      #
      # @param data_element_id [String] Adobe data element ID
      # @param attributes      [Hash]   Fields to update
      # @return [ReactorSDK::Resources::DataElement] The updated data element
      # @raise [ReactorSDK::ResourceNotFoundError] if the data element does not exist
      #
      def update(data_element_id, attributes)
        payload  = build_payload('data_elements', attributes, id: data_element_id)
        response = @connection.patch("/data_elements/#{data_element_id}", payload)
        @parser.parse(response['data'], Resources::DataElement)
      end

      ##
      # Deletes a data element permanently.
      #
      # @param data_element_id [String] Adobe data element ID
      # @return [nil]
      # @raise [ReactorSDK::ResourceNotFoundError] if the data element does not exist
      #
      def delete(data_element_id)
        @connection.delete("/data_elements/#{data_element_id}")
        nil
      end
    end
  end
end
