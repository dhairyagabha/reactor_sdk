# frozen_string_literal: true

##
# @file endpoints/hosts.rb
# @description Endpoint group for Adobe Launch Host resources.
#
#   Hosts define where Adobe Launch builds are deployed. A host ID is
#   required when creating an environment — fetch the property's hosts
#   first and pass the ID to environments.create.
#
#   Most properties have exactly one Adobe-managed Akamai host created
#   automatically. Use list_for_property to retrieve it.
#
# @domain Endpoints
# @see https://developer.adobe.com/experience-platform/documentation/tags/api/endpoints/hosts/
#

module ReactorSDK
  module Endpoints
    class Hosts < BaseEndpoint
      ##
      # Lists all hosts for a given property.
      # Follows pagination automatically — returns all hosts.
      #
      # Most properties have exactly one host — the Adobe-managed Akamai host.
      # Call this before creating an environment to obtain the host ID.
      #
      # @param property_id [String] Adobe property ID
      # @return [Array<ReactorSDK::Resources::Host>]
      # @raise [ReactorSDK::ResourceNotFoundError] if the property does not exist
      #
      def list_for_property(property_id)
        list_resources("/properties/#{property_id}/hosts", Resources::Host)
      end

      ##
      # Retrieves a single host by its Adobe ID.
      #
      # @param host_id [String] Adobe host ID (format: "HT" + hex string)
      # @return [ReactorSDK::Resources::Host]
      # @raise [ReactorSDK::ResourceNotFoundError] if the host does not exist
      #
      def find(host_id)
        fetch_resource("/hosts/#{host_id}", Resources::Host)
      end

      ##
      # Creates a host within a property.
      #
      # @param property_id [String] Adobe property ID
      # @param attributes  [Hash]   Host attributes exactly as accepted by Reactor
      # @return [ReactorSDK::Resources::Host]
      #
      def create(property_id:, attributes:)
        create_resource(
          "/properties/#{property_id}/hosts",
          'hosts',
          Resources::Host,
          attributes: attributes
        )
      end

      ##
      # Updates an existing host.
      #
      # @param host_id     [String] Adobe host ID
      # @param attributes  [Hash]   Fields to update
      # @return [ReactorSDK::Resources::Host]
      #
      def update(host_id, attributes)
        update_resource(
          "/hosts/#{host_id}",
          host_id,
          'hosts',
          Resources::Host,
          attributes: attributes
        )
      end

      ##
      # Deletes a host permanently.
      #
      # @param host_id [String] Adobe host ID
      # @return [nil]
      #
      def delete(host_id)
        delete_resource("/hosts/#{host_id}")
      end

      ##
      # Retrieves the property that owns a host.
      #
      # @param host_id [String] Adobe host ID
      # @return [ReactorSDK::Resources::Property]
      #
      def property(host_id)
        fetch_resource("/hosts/#{host_id}/property", Resources::Property)
      end
    end
  end
end
