# frozen_string_literal: true

##
# @file endpoints/companies.rb
# @description Endpoint group for Adobe Launch Company resources.
#
#   A Company maps to an Adobe IMS Organisation and is the top-level
#   container for all properties. Most orgs have exactly one company.
#
# @domain Endpoints
# @see https://developer.adobe.com/experience-platform/documentation/tags/api/endpoints/companies/
#

module ReactorSDK
  module Endpoints
    class Companies < BaseEndpoint
      ##
      # Lists all companies accessible to the authenticated token.
      # Follows pagination automatically — returns all companies.
      #
      # @return [Array<ReactorSDK::Resources::Company>]
      # @raise [ReactorSDK::AuthorizationError] if the token lacks access
      #
      def list
        records = @paginator.all("/companies")
        records.map { |r| @parser.parse(r, Resources::Company) }
      end

      ##
      # Retrieves a single company by its Adobe ID.
      #
      # @param company_id [String] Adobe company ID (format: "CO" + hex string)
      # @return [ReactorSDK::Resources::Company]
      # @raise [ReactorSDK::ResourceNotFoundError] if the company does not exist
      #
      def find(company_id)
        response = @connection.get("/companies/#{company_id}")
        @parser.parse(response["data"], Resources::Company)
      end
    end
  end
end
