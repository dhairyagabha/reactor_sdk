# frozen_string_literal: true

module ReactorSDK
  module Endpoints
    class Secrets < BaseEndpoint
      def list_for_property(property_id)
        list_resources("/properties/#{property_id}/secrets", Resources::Secret)
      end

      def list_for_environment(environment_id)
        list_resources("/environments/#{environment_id}/secrets", Resources::Secret)
      end

      def find(secret_id)
        fetch_resource("/secrets/#{secret_id}", Resources::Secret)
      end

      def create(property_id:, environment_id:, attributes:)
        create_resource(
          "/properties/#{property_id}/secrets",
          'secrets',
          Resources::Secret,
          attributes: attributes,
          relationships: {
            environment: {
              data: { id: environment_id, type: 'environments' }
            }
          }
        )
      end

      def test_or_retry(secret_id, type_of:, action:)
        update_resource(
          "/secrets/#{secret_id}",
          secret_id,
          'secrets',
          Resources::Secret,
          attributes: { type_of: type_of },
          meta: { action: action }
        )
      end

      def test(secret_id, type_of:)
        test_or_retry(secret_id, type_of: type_of, action: 'test')
      end

      def retry(secret_id, type_of:)
        test_or_retry(secret_id, type_of: type_of, action: 'retry')
      end

      def delete(secret_id)
        delete_resource("/secrets/#{secret_id}")
      end

      def data_elements(secret_id)
        list_resources("/secrets/#{secret_id}/data_elements", Resources::DataElement)
      end

      def environment(secret_id)
        fetch_resource("/secrets/#{secret_id}/environment", Resources::Environment)
      end

      def property(secret_id)
        fetch_resource("/secrets/#{secret_id}/property", Resources::Property)
      end

      def list_notes(secret_id)
        list_notes_for_path("/secrets/#{secret_id}/notes")
      end

      def create_note(secret_id, text)
        create_note_for_path("/secrets/#{secret_id}/notes", text)
      end
    end
  end
end
