# frozen_string_literal: true

##
# @file resources/environment.rb
# @description Represents an Adobe Launch Environment resource.
#
#   Environments map to deployment targets within a property.
#   Each property has three built-in environments: development,
#   staging, and production. Additional environments can be created
#   for personal developer sandboxes.
#
# @domain Resources
# @see https://developer.adobe.com/experience-platform/documentation/tags/api/endpoints/environments/
#

module ReactorSDK
  module Resources
    class Environment < BaseResource
      # @return [String] Display name of the environment
      attribute :name

      # @return [String] Stage — one of: "development", "staging", "production"
      attribute :stage

      # @return [Boolean] Whether the environment is archived
      attribute :archived, as: :boolean

      # @return [String, nil] Embed code for this environment
      attribute :token

      # @return [String] ISO8601 timestamp when the environment was created
      attribute :created_at

      # @return [String] ISO8601 timestamp when the environment was last updated
      attribute :updated_at

      ##
      # @return [String] Human-readable representation
      #
      def inspect
        "#<ReactorSDK::Resources::Environment id=#{id.inspect} name=#{name.inspect} stage=#{stage.inspect}>"
      end
    end
  end
end
