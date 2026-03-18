# frozen_string_literal: true

##
# @file endpoints/environments.rb
# @description Endpoint group for Adobe Launch Environment resources.
#
#   Environments map to deployment targets within a property.
#   Each property has three built-in environments (development, staging,
#   production). Additional environments can be created for personal
#   developer sandboxes — this is how LaunchGuard provisions per-developer
#   workspaces.
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
        records = @paginator.all("/properties/#{property_id}/environments")
        records.map { |r| @parser.parse(r, Resources::Environment) }
      end

      ##
      # Retrieves a single environment by its Adobe ID.
      #
      # @param environment_id [String] Adobe environment ID (format: "EN" + hex string)
      # @return [ReactorSDK::Resources::Environment]
      # @raise [ReactorSDK::ResourceNotFoundError] if the environment does not exist
      #
      def find(environment_id)
        response = @connection.get("/environments/#{environment_id}")
        @parser.parse(response['data'], Resources::Environment)
      end

      ##
      # Creates a new environment within a property.
      # Used by LaunchGuard to provision personal developer sandboxes.
      #
      # @param property_id [String] Adobe property ID
      # @param name        [String] Display name (e.g. "username-dev")
      # @param stage       [String] One of: "development", "staging", "production"
      # @return [ReactorSDK::Resources::Environment] The newly created environment
      # @raise [ReactorSDK::UnprocessableEntityError] if attributes are invalid
      #
      def create(property_id:, name:, stage: 'development')
        payload  = build_payload('environments', { name: name, stage: stage })
        response = @connection.post("/properties/#{property_id}/environments", payload)
        @parser.parse(response['data'], Resources::Environment)
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
        @connection.delete("/environments/#{environment_id}")
        nil
      end
    end
  end
end
