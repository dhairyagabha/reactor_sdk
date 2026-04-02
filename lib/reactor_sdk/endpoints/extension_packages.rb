# frozen_string_literal: true

module ReactorSDK
  module Endpoints
    class ExtensionPackages < BaseEndpoint
      def list(params: {})
        list_resources('/extension_packages', Resources::ExtensionPackage, params: params)
      end

      def find(extension_package_id)
        fetch_resource("/extension_packages/#{extension_package_id}", Resources::ExtensionPackage)
      end

      def create(package_path:)
        response = @connection.post_multipart('/extension_packages', file_path: package_path)
        @parser.parse(response['data'], Resources::ExtensionPackage, response: response)
      end

      def update(extension_package_id, package_path:)
        response = @connection.post_multipart(
          "/extension_packages/#{extension_package_id}",
          file_path: package_path
        )
        @parser.parse(response['data'], Resources::ExtensionPackage, response: response)
      end

      def private_release(extension_package_id)
        transition(extension_package_id, action: 'release_private')
      end

      def discontinue(extension_package_id)
        transition(extension_package_id, action: 'discontinue')
      end

      def versions(extension_package_id)
        list_resources(
          "/extension_packages/#{extension_package_id}/versions",
          Resources::ExtensionPackage
        )
      end

      def usage_authorizations(extension_package_id)
        list_resources(
          "/extension_packages/#{extension_package_id}/extension_package_usage_authorizations",
          Resources::ExtensionPackageUsageAuthorization
        )
      end

      private

      def transition(extension_package_id, action:)
        update_resource(
          "/extension_packages/#{extension_package_id}",
          extension_package_id,
          'extension_packages',
          Resources::ExtensionPackage,
          attributes: {},
          meta: { action: action }
        )
      end
    end
  end
end
