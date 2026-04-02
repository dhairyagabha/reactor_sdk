# frozen_string_literal: true

module ReactorSDK
  module Endpoints
    class ExtensionPackageUsageAuthorizations < BaseEndpoint
      def list
        list_resources(
          '/extension_package_usage_authorizations',
          Resources::ExtensionPackageUsageAuthorization
        )
      end

      def list_for_package(extension_package_id)
        list_resources(
          "/extension_packages/#{extension_package_id}/extension_package_usage_authorizations",
          Resources::ExtensionPackageUsageAuthorization
        )
      end

      def create(extension_package_id:, authorized_org_id:)
        create_resource(
          "/extension_packages/#{extension_package_id}/extension_package_usage_authorizations",
          'extension_package_usage_authorizations',
          Resources::ExtensionPackageUsageAuthorization,
          attributes: { authorized_org_id: authorized_org_id }
        )
      end

      def update(authorization_id, state:)
        update_resource(
          "/extension_package_usage_authorizations/#{authorization_id}",
          authorization_id,
          'extension_package_usage_authorizations',
          Resources::ExtensionPackageUsageAuthorization,
          attributes: { state: state }
        )
      end

      def delete(authorization_id)
        delete_resource("/extension_package_usage_authorizations/#{authorization_id}")
      end

      def extension_package(authorization_id)
        fetch_resource(
          "/extension_package_usage_authorizations/#{authorization_id}/extension_package",
          Resources::ExtensionPackage
        )
      end
    end
  end
end
