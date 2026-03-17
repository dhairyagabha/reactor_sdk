# frozen_string_literal: true

##
# @file resources/company.rb
# @description Represents an Adobe Launch Company resource.
#
#   A Company maps directly to an Adobe IMS Organisation. It is the
#   top-level container — all properties belong to a company.
#   Most orgs have exactly one company.
#
# @domain Resources
# @see https://developer.adobe.com/experience-platform/documentation/tags/api/endpoints/companies/
#

module ReactorSDK
  module Resources
    class Company < BaseResource
      # @return [String] Display name of the company
      attribute :name

      # @return [String] Adobe IMS organisation ID
      attribute :org_id

      # @return [String] ISO8601 timestamp when the company was created
      attribute :created_at

      # @return [String] ISO8601 timestamp when the company was last updated
      attribute :updated_at

      ##
      # @return [String] Human-readable representation
      #
      def inspect
        "#<ReactorSDK::Resources::Company id=#{id.inspect} name=#{name.inspect}>"
      end
    end
  end
end
