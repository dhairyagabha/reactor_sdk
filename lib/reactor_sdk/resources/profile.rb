# frozen_string_literal: true

module ReactorSDK
  module Resources
    class Profile < BaseResource
      attribute :active_org
      attribute :expires_in
      attribute :display_name
      attribute :job_function
      attribute :email
      attribute :organizations, default: {}

      def rights
        Array(meta['rights'])
      end

      def inspect
        "#<ReactorSDK::Resources::Profile id=#{id.inspect} email=#{email.inspect}>"
      end
    end
  end
end
