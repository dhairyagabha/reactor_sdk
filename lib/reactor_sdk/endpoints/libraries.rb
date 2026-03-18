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
#   - create              creates a new library in a property
#   - add_resources       associates rules/data elements/extensions
#   - build               triggers a build (compiles the bundle)
#   - transition          moves the library through its state machine
#   - find_with_resources fetches library with all included resources
#                         and their current revision IDs attached
#   - upstream_libraries  returns ordered list of libraries upstream
#                         of a given library in the environment chain
#                         (Development → Staging → Production)
#
# @domain Endpoints
# @see https://developer.adobe.com/experience-platform/documentation/tags/api/endpoints/libraries/
#

module ReactorSDK
  module Endpoints
    class Libraries < BaseEndpoint

      # Adobe Launch environment stages in upstream order.
      # Development is at the bottom — Production is at the top.
      UPSTREAM_STAGE_ORDER = %w[development staging production].freeze

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
      # Fetches a library with all its associated resources included.
      #
      # Calls GET /libraries/:id?include=rules,data_elements,extensions
      # which returns the library alongside all its resources in the
      # JSON:API included array. Each included resource carries its
      # current revision ID in its relationships hash.
      #
      # Returns a LibraryWithResources object exposing:
      #   - All standard library attributes
      #   - rules, data_elements, extensions arrays with revision_id attached
      #   - resource_index for quick revision ID lookup by resource ID
      #
      # This is the primary method for gathering data needed for upstream
      # resolution — call it on both the source and target library, then
      # compare their resource_index hashes to find what changed.
      #
      # @param library_id [String] Adobe library ID
      # @return [ReactorSDK::Resources::LibraryWithResources]
      # @raise [ReactorSDK::ResourceNotFoundError] if the library does not exist
      #
      def find_with_resources(library_id)
        response = @connection.get(
          "/libraries/#{library_id}",
          params: { "include" => "rules,data_elements,extensions" }
        )

        build_library_with_resources(response)
      end

      ##
      # Returns the ordered list of libraries upstream of the given library.
      #
      # Adobe Launch uses an environment hierarchy where changes flow upward:
      # Personal Dev → Development → Staging → Production
      #
      # "Upstream" means closer to Production. When a resource does not exist
      # in the target library, the app walks this list in order to find the
      # nearest upstream version to diff against.
      #
      # Examples:
      #   Target is Development → returns [staging_library, production_library]
      #   Target is Staging     → returns [production_library]
      #   Target is Production  → returns [] (nothing upstream)
      #
      # Fetches all libraries for the property and filters by environment stage.
      # Returns them in upstream order — nearest first, Production last.
      #
      # @param library_id  [String] Adobe library ID of the target library
      # @param property_id [String] Adobe property ID
      # @return [Array<ReactorSDK::Resources::Library>] Upstream libraries, nearest first
      # @raise [ReactorSDK::ResourceNotFoundError] if either resource does not exist
      #
      def upstream_libraries(library_id, property_id:)
        target   = find(library_id)
        target_stage = fetch_library_stage(library_id)

        return [] if target_stage.nil?
        return [] if target_stage == "production"

        upstream_stages = stages_above(target_stage)
        all_libraries   = list_for_property(property_id)

        upstream_stages.filter_map do |stage|
          all_libraries.find do |lib|
            fetch_library_stage(lib.id) == stage
          end
        end
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
      # @param library_id       [String]        Adobe library ID
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
      # @param library_id    [String]        Adobe library ID
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
      #
      # @param library_id [String] Adobe library ID
      # @return [ReactorSDK::Resources::Build] The triggered build
      # @raise [ReactorSDK::UnprocessableEntityError] if the library cannot be built
      #
      def build(library_id)
        response = @connection.post("/libraries/#{library_id}/builds", {})
        @parser.parse(response["data"], Resources::Build)
      end

      private

      ##
      # Builds a LibraryWithResources from a full API response that includes
      # rules, data_elements, and extensions in the included array.
      #
      # Groups the included array by resource type and passes each group
      # to LibraryWithResources for typed resource construction.
      #
      # @param response [Hash] Full JSON:API response from the API
      # @return [ReactorSDK::Resources::LibraryWithResources]
      #
      def build_library_with_resources(response)
        data     = response.fetch("data")
        included = Array(response["included"])

        included_by_type = included.group_by { |r| r["type"] }

        Resources::LibraryWithResources.new(
          id:                 data.fetch("id"),
          type:               data.fetch("type"),
          attributes:         data.fetch("attributes", {}),
          meta:               data.fetch("meta", {}),
          included_resources: {
            "rules"         => included_by_type.fetch("rules",         []),
            "data_elements" => included_by_type.fetch("data_elements", []),
            "extensions"    => included_by_type.fetch("extensions",    [])
          }
        )
      end

      ##
      # Fetches the environment stage for a library by following its
      # environment relationship.
      #
      # Calls GET /libraries/:id/relationships/environment to get the
      # environment ID, then GET /environments/:id to get the stage.
      #
      # @param library_id [String] Adobe library ID
      # @return [String, nil] Stage ("development", "staging", "production") or nil
      #
      def fetch_library_stage(library_id)
        env_rel  = @connection.get("/libraries/#{library_id}/relationships/environment")
        env_id   = env_rel&.dig("data", "id")
        return nil unless env_id

        env_response = @connection.get("/environments/#{env_id}")
        env_response&.dig("data", "attributes", "stage")
      end

      ##
      # Returns the stages that are upstream of the given stage.
      # Ordered nearest-first (e.g. development → [staging, production]).
      #
      # @param stage [String] Current stage
      # @return [Array<String>] Upstream stages in order
      #
      def stages_above(stage)
        current_index = UPSTREAM_STAGE_ORDER.index(stage)
        return [] if current_index.nil?

        UPSTREAM_STAGE_ORDER[(current_index + 1)..]
      end
    end
  end
end
