# frozen_string_literal: true

##
# @file endpoints/libraries.rb
# @description Endpoint group for Adobe Launch Library resources.
#
#   Libraries collect rules, data elements, and extensions into a
#   deployable bundle. They move through a state machine:
#   development -> submitted -> approved -> rejected -> published.
#
#   Key operations for LaunchGuard:
#   - create        creates a new library in a property
#   - add_resources associates rules/data elements/extensions with a library
#   - build         triggers a build (compiles the bundle)
#   - transition    moves the library through its state machine
#
# @domain Endpoints
# @see https://developer.adobe.com/experience-platform/documentation/tags/api/endpoints/libraries/
#

module ReactorSDK
  module Endpoints
    class Libraries < BaseEndpoint
      ##
      # Lists all libraries for a given property.
      # Follows pagination automatically — returns all libraries.
      #
      # @param property_id [String] Adobe property ID
      # @return [Array<ReactorSDK::Resources::Library>]
      # @raise [ReactorSDK::ResourceNotFoundError] if the property does not exist
      #
      def list_for_property(property_id)
        records = @paginator.all("/properties/#{property_id}/libraries")
        records.map { |r| @parser.parse(r, Resources::Library) }
      end

      ##
      # Retrieves a single library by its Adobe ID.
      #
      # @param library_id [String] Adobe library ID (format: "LB" + hex string)
      # @return [ReactorSDK::Resources::Library]
      # @raise [ReactorSDK::ResourceNotFoundError] if the library does not exist
      #
      def find(library_id)
        response = @connection.get("/libraries/#{library_id}")
        @parser.parse(response["data"], Resources::Library)
      end

      ##
      # Creates a new library within a property.
      #
      # @param property_id [String] Adobe property ID
      # @param name        [String] Display name for the library
      # @return [ReactorSDK::Resources::Library] The newly created library
      # @raise [ReactorSDK::UnprocessableEntityError] if attributes are invalid
      #
      def create(property_id:, name:)
        payload  = build_payload("libraries", { name: name })
        response = @connection.post("/properties/#{property_id}/libraries", payload)
        @parser.parse(response["data"], Resources::Library)
      end

      ##
      # Adds rules to a library by relationship.
      # Rules must be added before a library can be built.
      #
      # @param library_id [String]        Adobe library ID
      # @param rule_ids   [Array<String>] Adobe rule IDs to add
      # @return [nil]
      # @raise [ReactorSDK::ResourceNotFoundError] if the library does not exist
      #
      def add_rules(library_id, rule_ids)
        payload = build_relationship_payload("rules", rule_ids)
        @connection.post("/libraries/#{library_id}/relationships/rules", payload)
        nil
      end

      ##
      # Adds data elements to a library by relationship.
      #
      # @param library_id      [String]        Adobe library ID
      # @param data_element_ids [Array<String>] Adobe data element IDs to add
      # @return [nil]
      # @raise [ReactorSDK::ResourceNotFoundError] if the library does not exist
      #
      def add_data_elements(library_id, data_element_ids)
        payload = build_relationship_payload("data_elements", data_element_ids)
        @connection.post("/libraries/#{library_id}/relationships/data_elements", payload)
        nil
      end

      ##
      # Adds extensions to a library by relationship.
      #
      # @param library_id   [String]        Adobe library ID
      # @param extension_ids [Array<String>] Adobe extension IDs to add
      # @return [nil]
      # @raise [ReactorSDK::ResourceNotFoundError] if the library does not exist
      #
      def add_extensions(library_id, extension_ids)
        payload = build_relationship_payload("extensions", extension_ids)
        @connection.post("/libraries/#{library_id}/relationships/extensions", payload)
        nil
      end

      ##
      # Assigns an environment to a library.
      # A library must have an environment assigned before it can be built.
      #
      # @param library_id     [String] Adobe library ID
      # @param environment_id [String] Adobe environment ID to assign
      # @return [nil]
      # @raise [ReactorSDK::ResourceNotFoundError] if either resource does not exist
      #
      def assign_environment(library_id, environment_id)
        payload = { data: { id: environment_id, type: "environments" } }
        @connection.patch("/libraries/#{library_id}/relationships/environment", payload)
        nil
      end

      ##
      # Transitions a library to a new state in its workflow.
      # Valid transitions depend on current state and user permissions.
      #
      # State machine:
      #   development -> submitted -> approved -> published
      #                           -> rejected -> development
      #
      # @param library_id [String] Adobe library ID
      # @param state      [String] Target state to transition to
      # @return [ReactorSDK::Resources::Library] The updated library
      # @raise [ReactorSDK::UnprocessableEntityError] if the transition is invalid
      #
      def transition(library_id, state:)
        payload  = build_payload("libraries", { state: state }, id: library_id)
        response = @connection.patch("/libraries/#{library_id}", payload)
        @parser.parse(response["data"], Resources::Library)
      end

      ##
      # Triggers a build for a library.
      # The library must be in "development" state and have an environment assigned.
      #
      # @param library_id [String] Adobe library ID
      # @return [ReactorSDK::Resources::Build] The triggered build
      # @raise [ReactorSDK::UnprocessableEntityError] if the library cannot be built
      #
      def build(library_id)
        response = @connection.post("/libraries/#{library_id}/builds", {})
        @parser.parse(response["data"], Resources::Build)
      end
    end
  end
end
