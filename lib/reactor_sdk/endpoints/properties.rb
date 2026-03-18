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
        records = @paginator.all("/companies/#{company_id}/properties")
        records.map { |r| @parser.parse(r, Resources::Property) }
      end

      ##
      # Retrieves a single property by its Adobe ID.
      #
      # @param property_id [String] Adobe property ID (format: "PR" + hex string)
      # @return [ReactorSDK::Resources::Property]
      # @raise [ReactorSDK::ResourceNotFoundError] if the property does not exist
      #
      def find(property_id)
        response = @connection.get("/properties/#{property_id}")
        @parser.parse(response['data'], Resources::Property)
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
        payload = build_payload(
          'properties',
          { name: name, platform: platform, domains: domains }
        )
        response = @connection.post("/companies/#{company_id}/properties", payload)
        @parser.parse(response['data'], Resources::Property)
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
        payload  = build_payload('properties', attributes, id: property_id)
        response = @connection.patch("/properties/#{property_id}", payload)
        @parser.parse(response['data'], Resources::Property)
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
        @connection.delete("/properties/#{property_id}")
        nil
      end
    end
  end
end
