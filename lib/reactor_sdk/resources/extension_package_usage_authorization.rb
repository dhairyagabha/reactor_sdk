# frozen_string_literal: true

module ReactorSDK
  module Resources
    class ExtensionPackageUsageAuthorization < BaseResource
      attribute :name
      attribute :platform
      attribute :owner_org_id
      attribute :owner_org_name
      attribute :authorized_org_id
      attribute :authorized_org_name
      attribute :state
      attribute :created_by_email
      attribute :created_by_display_name
      attribute :updated_by_email
      attribute :updated_by_display_name
      attribute :created_at
      attribute :updated_at

      def inspect
        '#<ReactorSDK::Resources::ExtensionPackageUsageAuthorization ' \
          "id=#{id.inspect} authorized_org_id=#{authorized_org_id.inspect} state=#{state.inspect}>"
      end
    end
  end
end
