# frozen_string_literal: true

module ReactorSDK
  module Resources
    class AppConfiguration < BaseResource
      attribute :name
      attribute :app_id
      attribute :platform
      attribute :messaging_service
      attribute :key_type
      attribute :push_credential, default: {}
      attribute :created_at
      attribute :updated_at

      def inspect
        "#<ReactorSDK::Resources::AppConfiguration id=#{id.inspect} name=#{name.inspect}>"
      end
    end
  end
end
