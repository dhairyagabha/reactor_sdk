# frozen_string_literal: true

##
# @file endpoints/data_elements.rb
# @description Endpoint group for Adobe Launch Data Element resources.
#
#   Data elements are reusable values that can be referenced throughout
#   rules and other data elements. They form the data layer of Adobe Launch.
#
#   Creating a data element requires an extension relationship in the payload.
#   Fetch the property's extensions first to obtain the extension_id.
#
#   Important: data elements must be revised before they can be added to
#   a library. Call revise(data_element_id) before libraries.add_data_elements.
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
      # @param data_element_id [String] Adobe data element ID (format: "DE" + hex)
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
      # Requires an extension_id — fetch the property's extensions first:
      #   extensions  = client.extensions.list_for_property(property_id)
      #   extension_id = extensions.find { |e| e.delegate_descriptor_id.start_with?("core::") }.id
      #
      # The settings field must be a JSON-encoded string matching the delegate
      # schema. For Core custom code the settings schema only allows "source" —
      # do NOT include "language":
      #   settings: JSON.generate({ source: "return document.title;" })
      #
      # @param property_id            [String]  Adobe property ID
      # @param name                   [String]  Display name
      # @param delegate_descriptor_id [String]  Extension delegate identifier
      # @param settings               [String]  JSON-encoded settings string
      # @param extension_id           [String]  Adobe extension ID
      # @param enabled                [Boolean] Whether enabled (default: true)
      # @return [ReactorSDK::Resources::DataElement]
      # @raise [ReactorSDK::UnprocessableEntityError] if attributes are invalid
      #
      def create(
        property_id:,
        name:,
        delegate_descriptor_id:,
        settings:,
        extension_id:,
        enabled: true
      )
        payload  = build_data_element_payload(
          name, delegate_descriptor_id, settings, extension_id, enabled
        )
        response = @connection.post("/properties/#{property_id}/data_elements", payload)
        @parser.parse(response['data'], Resources::DataElement)
      end

      ##
      # Updates an existing data element.
      #
      # @param data_element_id [String] Adobe data element ID
      # @param attributes      [Hash]   Fields to update
      # @return [ReactorSDK::Resources::DataElement]
      # @raise [ReactorSDK::ResourceNotFoundError] if the data element does not exist
      #
      def update(data_element_id, attributes)
        payload  = build_payload('data_elements', attributes, id: data_element_id)
        response = @connection.patch("/data_elements/#{data_element_id}", payload)
        @parser.parse(response['data'], Resources::DataElement)
      end

      ##
      # Revises a data element so it can be added to a library.
      #
      # Adobe Launch requires every resource to be explicitly revised before
      # it can be added to a library.
      #
      # Always call revise after create or update, before libraries.add_data_elements.
      #
      # @param data_element_id [String] Adobe data element ID
      # @return [ReactorSDK::Resources::DataElement] The revised data element
      # @raise [ReactorSDK::ResourceNotFoundError] if the data element does not exist
      #
      def revise(data_element_id)
        payload = {
          data: {
            id: data_element_id,
            type: 'data_elements',
            meta: { action: 'revise' }
          }
        }
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

      ##
      # Lists notes attached to a data element.
      #
      # @param data_element_id [String]
      # @return [Array<ReactorSDK::Resources::Note>]
      #
      def list_notes(data_element_id)
        list_notes_for_path("/data_elements/#{data_element_id}/notes")
      end

      ##
      # Creates a note on a data element.
      #
      # @param data_element_id [String]
      # @param text [String]
      # @return [ReactorSDK::Resources::Note]
      #
      def create_note(data_element_id, text)
        create_note_for_path("/data_elements/#{data_element_id}/notes", text)
      end

      private

      ##
      # Builds the JSON:API payload for data element creation.
      # Includes the required extension relationship.
      #
      # @param name                   [String]  Display name
      # @param delegate_descriptor_id [String]  Delegate identifier
      # @param settings               [String]  JSON-encoded settings
      # @param extension_id           [String]  Extension providing the delegate
      # @param enabled                [Boolean] Whether enabled
      # @return [Hash] JSON:API compliant payload
      #
      def build_data_element_payload(name, delegate_descriptor_id, settings, extension_id, enabled)
        {
          data: {
            type: 'data_elements',
            attributes: {
              name: name,
              delegate_descriptor_id: delegate_descriptor_id,
              settings: settings,
              enabled: enabled
            },
            relationships: {
              extension: {
                data: { id: extension_id, type: 'extensions' }
              }
            }
          }
        }
      end
    end
  end
end
