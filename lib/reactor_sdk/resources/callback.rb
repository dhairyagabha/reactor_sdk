# frozen_string_literal: true

module ReactorSDK
  module Resources
    class Callback < BaseResource
      attribute :url
      attribute :subscriptions, default: []
      attribute :created_at
      attribute :updated_at

      def inspect
        "#<ReactorSDK::Resources::Callback id=#{id.inspect} url=#{url.inspect}>"
      end
    end
  end
end
