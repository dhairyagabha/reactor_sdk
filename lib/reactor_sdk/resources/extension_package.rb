# frozen_string_literal: true

##
# @file resources/extension_package.rb
# @description Represents an Adobe Launch Extension Package resource.
#
#   Extension packages are the installable packages behind property extensions.
#   They are returned when traversing extension relationships or audit events
#   that reference package changes.
#
# @domain Resources
#

module ReactorSDK
  module Resources
    class ExtensionPackage < BaseResource
      # @return [String] Package name
      attribute :name

      # @return [String, nil] Human-readable display name
      attribute :display_name

      # @return [String, nil] Supported platform, such as "web" or "edge"
      attribute :platform

      # @return [String, nil] Package availability
      attribute :availability

      # @return [String, nil] Package version
      attribute :version

      # @return [String] ISO8601 timestamp when the package was created
      attribute :created_at

      # @return [String] ISO8601 timestamp when the package was last updated
      attribute :updated_at

      ##
      # @return [String] Human-readable representation
      #
      def inspect
        '#<ReactorSDK::Resources::ExtensionPackage ' \
          "id=#{id.inspect} " \
          "name=#{name.inspect} " \
          "version=#{version.inspect}>"
      end
    end
  end
end
