# frozen_string_literal: true

module ReactorSDK
  module Endpoints
    class AppConfigurations < BaseEndpoint
      def list_for_company(company_id)
        list_resources("/companies/#{company_id}/app_configurations", Resources::AppConfiguration)
      end

      def find(config_id)
        fetch_resource("/app_configurations/#{config_id}", Resources::AppConfiguration)
      end

      def create(company_id:, attributes:)
        create_resource(
          "/companies/#{company_id}/app_configurations",
          'app_configurations',
          Resources::AppConfiguration,
          attributes: attributes
        )
      end

      def update(config_id, attributes)
        update_resource(
          "/app_configurations/#{config_id}",
          config_id,
          'app_configurations',
          Resources::AppConfiguration,
          attributes: attributes
        )
      end

      def delete(config_id)
        delete_resource("/app_configurations/#{config_id}")
      end

      def company(config_id)
        fetch_resource("/app_configurations/#{config_id}/company", Resources::Company)
      end
    end
  end
end
