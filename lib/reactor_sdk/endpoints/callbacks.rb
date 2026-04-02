# frozen_string_literal: true

module ReactorSDK
  module Endpoints
    class Callbacks < BaseEndpoint
      def list_for_property(property_id)
        list_resources("/properties/#{property_id}/callbacks", Resources::Callback)
      end

      def find(callback_id)
        fetch_resource("/callbacks/#{callback_id}", Resources::Callback)
      end

      def create(property_id:, attributes:)
        create_resource(
          "/properties/#{property_id}/callbacks",
          'callbacks',
          Resources::Callback,
          attributes: attributes
        )
      end

      def update(callback_id, attributes)
        update_resource(
          "/callbacks/#{callback_id}",
          callback_id,
          'callbacks',
          Resources::Callback,
          attributes: attributes
        )
      end

      def delete(callback_id)
        delete_resource("/callbacks/#{callback_id}")
      end
    end
  end
end
