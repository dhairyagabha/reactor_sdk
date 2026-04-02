# frozen_string_literal: true

module ReactorSDK
  module Resources
    class Secret < BaseResource
      attribute :name
      attribute :type_of
      attribute :credentials, default: {}
      attribute :created_at
      attribute :updated_at

      def inspect
        "#<ReactorSDK::Resources::Secret id=#{id.inspect} name=#{name.inspect} type_of=#{type_of.inspect}>"
      end
    end
  end
end
