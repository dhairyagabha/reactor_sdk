# frozen_string_literal: true

##
# @file endpoints/environments.rb
# @description Endpoint group for Adobe Launch Environment resources.
#
#   Environments map to deployment targets within a property.
#   Each property has three built-in environments: development, staging,
#   and production. Additional environments can be created for personal
#   developer sandboxes — this is how LaunchGuard provisions per-developer
#   workspaces.
#
#   Important: the Reactor API requires a host relationship when creating
#   an environment. Fetch the property's hosts first and pass the host_id
#   to the create method. Most properties have exactly one Akamai host.
#
#   Example:
#     hosts = client.hosts.list_for_property(property_id)
#     client.environments.create(
#       property_id: property_id,
#       name:        "jsmith-dev",
#       stage:       "development",
#       host_id:     hosts.first.id
#     )
#
# @domain Endpoints
# @see https://developer.adobe.com/experience-platform/documentation/tags/api/endpoints/environments/
#

module ReactorSDK
  module Endpoints
    class Environments < BaseEndpoint
      ##
      # Lists all environments for a given property.
      # Follows pagination automatically — returns all environments.
      #
      # @param property_id [String] Adobe property ID
      # @return [Array<ReactorSDK::Resources::Environment>]
      # @raise [ReactorSDK::ResourceNotFoundError] if the property does not exist
      #
      def list_for_property(property_id)
        list_resources("/properties/#{property_id}/environments", Resources::Environment)
      end

      ##
      # Retrieves a single environment by its Adobe ID.
      #
      # @param environment_id [String] Adobe environment ID (format: "EN" + hex string)
      # @return [ReactorSDK::Resources::Environment]
      # @raise [ReactorSDK::ResourceNotFoundError] if the environment does not exist
      #
      def find(environment_id)
        fetch_resource("/environments/#{environment_id}", Resources::Environment)
      end

      ##
      # Creates a new environment within a property.
      #
      # Requires a host_id — fetch the property's hosts first:
      #   hosts = client.hosts.list_for_property(property_id)
      #   host_id = hosts.first.id
      #
      # Used by LaunchGuard to provision personal developer sandboxes
      # when a new user joins an organisation.
      #
      # @param property_id [String] Adobe property ID
      # @param name        [String] Display name (e.g. "jsmith-dev")
      # @param stage       [String] One of: "development", "staging", "production"
      # @param host_id     [String] Adobe host ID — required by the Reactor API
      # @return [ReactorSDK::Resources::Environment] The newly created environment
      # @raise [ReactorSDK::UnprocessableEntityError] if attributes are invalid
      # @raise [ReactorSDK::ConfigurationError] if host_id is blank
      #
      def create(property_id:, name:, host_id:, stage: 'development')
        if host_id.nil? || host_id.strip.empty?
          raise ConfigurationError,
                'host_id is required to create an environment. ' \
                'Fetch the property hosts first: client.hosts.list_for_property(property_id)'
        end

        create_resource(
          "/properties/#{property_id}/environments",
          'environments',
          Resources::Environment,
          attributes: { name: name, stage: stage },
          relationships: {
            host: {
              data: { id: host_id, type: 'hosts' }
            }
          }
        )
      end

      ##
      # Updates an existing environment.
      #
      # @param environment_id [String] Adobe environment ID
      # @param attributes     [Hash]   Fields to update
      # @return [ReactorSDK::Resources::Environment]
      #
      def update(environment_id, attributes)
        update_resource(
          "/environments/#{environment_id}",
          environment_id,
          'environments',
          Resources::Environment,
          attributes: attributes
        )
      end

      ##
      # Retrieves the host assigned to an environment.
      #
      # @param environment_id [String] Adobe environment ID
      # @return [ReactorSDK::Resources::Host]
      #
      def host(environment_id)
        fetch_resource("/environments/#{environment_id}/host", Resources::Host)
      end

      ##
      # Retrieves the raw host relationship linkage for an environment.
      #
      # @param environment_id [String] Adobe environment ID
      # @return [Hash, nil]
      #
      def host_relationship(environment_id)
        fetch_relationship("/environments/#{environment_id}/relationships/host")
      end

      ##
      # Retrieves the library currently assigned to an environment.
      #
      # @param environment_id [String] Adobe environment ID
      # @return [ReactorSDK::Resources::Library]
      #
      def library(environment_id)
        fetch_resource("/environments/#{environment_id}/library", Resources::Library)
      end

      ##
      # Retrieves the property that owns an environment.
      #
      # @param environment_id [String] Adobe environment ID
      # @return [ReactorSDK::Resources::Property]
      #
      def property(environment_id)
        fetch_resource("/environments/#{environment_id}/property", Resources::Property)
      end

      ##
      # Lists builds produced for an environment.
      #
      # @param environment_id [String] Adobe environment ID
      # @return [Array<ReactorSDK::Resources::Build>]
      #
      def builds(environment_id)
        list_resources("/environments/#{environment_id}/builds", Resources::Build)
      end

      ##
      # Deletes an environment permanently.
      # Only non-built-in environments (personal sandboxes) should be deleted.
      #
      # @param environment_id [String] Adobe environment ID
      # @return [nil]
      # @raise [ReactorSDK::ResourceNotFoundError] if the environment does not exist
      #
      def delete(environment_id)
        delete_resource("/environments/#{environment_id}")
      end
    end
  end
end
