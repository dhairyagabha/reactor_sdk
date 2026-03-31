# frozen_string_literal: true

##
# @file resources/host.rb
# @description Represents an Adobe Launch Host resource.
#
#   Hosts define where Adobe Launch builds are deployed. Every environment
#   requires a host assignment before it can be created. Adobe manages
#   the default Akamai host automatically — most properties have exactly
#   one host of type "akamai".
#
#   Hosts must be fetched before creating an environment so the correct
#   host ID can be included in the environment creation payload.
#
# @domain Resources
# @see https://developer.adobe.com/experience-platform/documentation/tags/api/endpoints/hosts/
#

module ReactorSDK
  module Resources
    class Host < BaseResource
      # @return [String] Display name of the host
      attribute :name

      # @return [String] Host type — typically "akamai" for Adobe-managed hosts
      attribute :type_of

      # @return [String] Host status — "succeeded", "failed", "pending"
      attribute :status

      # @return [String] ISO8601 timestamp when the host was created
      attribute :created_at

      # @return [String] ISO8601 timestamp when the host was last updated
      attribute :updated_at

      ##
      # Returns true if the host is an Adobe-managed Akamai host.
      # Most properties have exactly one Akamai host by default.
      #
      # @return [Boolean]
      #
      def akamai?
        type_of == 'akamai'
      end

      ##
      # Returns true if the host is ready for use.
      #
      # @return [Boolean]
      #
      def ready?
        status == 'succeeded'
      end

      ##
      # @return [String] Human-readable representation
      #
      def inspect
        '#<ReactorSDK::Resources::Host ' \
          "id=#{id.inspect} " \
          "name=#{name.inspect} " \
          "type_of=#{type_of.inspect} " \
          "status=#{status.inspect}>"
      end
    end
  end
end
