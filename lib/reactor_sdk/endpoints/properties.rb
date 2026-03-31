# frozen_string_literal: true

##
# @file endpoints/properties.rb
# @description Endpoint group for Adobe Launch Property resources.
#
#   Properties are the primary container in Adobe Launch. All rules,
#   data elements, extensions, environments, and libraries belong to
#   a property. A company can have many properties.
#
# @domain Endpoints
# @see https://developer.adobe.com/experience-platform/documentation/tags/api/endpoints/properties/
#

module ReactorSDK
  module Endpoints
    class Properties < BaseEndpoint
      ##
      # Lists all properties for a given company.
      # Follows pagination automatically — returns all properties.
      #
      # @param company_id [String] Adobe company ID (format: "CO" + hex string)
      # @return [Array<ReactorSDK::Resources::Property>]
      # @raise [ReactorSDK::ResourceNotFoundError] if the company does not exist
      # @raise [ReactorSDK::AuthorizationError] if the token cannot access this company
      #
      def list_for_company(company_id)
        list_resources("/companies/#{company_id}/properties", Resources::Property)
      end

      ##
      # Retrieves a single property by its Adobe ID.
      #
      # @param property_id [String] Adobe property ID (format: "PR" + hex string)
      # @return [ReactorSDK::Resources::Property]
      # @raise [ReactorSDK::ResourceNotFoundError] if the property does not exist
      #
      def find(property_id)
        fetch_resource("/properties/#{property_id}", Resources::Property)
      end

      ##
      # Retrieves the company that owns a property.
      #
      # @param property_id [String] Adobe property ID
      # @return [ReactorSDK::Resources::Company]
      #
      def company(property_id)
        fetch_resource("/properties/#{property_id}/company", Resources::Company)
      end

      ##
      # Creates a new property within a company.
      #
      # @param company_id [String]        Adobe company ID
      # @param name       [String]        Display name for the property
      # @param platform   [String]        One of: "web", "mobile", "edge"
      # @param domains    [Array<String>] Domains — required for web properties
      # @return [ReactorSDK::Resources::Property] The newly created property
      # @raise [ReactorSDK::UnprocessableEntityError] if attributes are invalid
      #
      def create(company_id:, name:, platform:, domains: [])
        create_resource(
          "/companies/#{company_id}/properties",
          'properties',
          Resources::Property,
          attributes: { name: name, platform: platform, domains: domains }
        )
      end

      ##
      # Updates an existing property.
      #
      # @param property_id [String] Adobe property ID
      # @param attributes  [Hash]   Fields to update (e.g. { name: "New Name" })
      # @return [ReactorSDK::Resources::Property] The updated property
      # @raise [ReactorSDK::ResourceNotFoundError] if the property does not exist
      #
      def update(property_id, attributes)
        update_resource(
          "/properties/#{property_id}",
          property_id,
          'properties',
          Resources::Property,
          attributes: attributes
        )
      end

      ##
      # Deletes a property permanently. This action cannot be undone.
      # All child resources (rules, data elements, environments) are also deleted.
      #
      # @param property_id [String] Adobe property ID
      # @return [nil]
      # @raise [ReactorSDK::ResourceNotFoundError] if the property does not exist
      #
      def delete(property_id)
        delete_resource("/properties/#{property_id}")
      end

      ##
      # Creates a note on a property.
      #
      # @param property_id [String] Adobe property ID
      # @param text        [String] Note body text
      # @return [ReactorSDK::Resources::Note]
      #
      def create_note(property_id, text)
        create_note_for_path("/properties/#{property_id}/notes", text)
      end
    end
  end
end
