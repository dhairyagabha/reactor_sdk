# frozen_string_literal: true

##
# @file endpoints/libraries.rb
# @description Endpoint group for Adobe Launch Library resources.
#
#   Libraries collect rules, data elements, and extensions into a
#   deployable bundle. They move through a state machine:
#   development -> submitted -> approved -> rejected -> published.
#
#   Resource management methods follow JSON:API relationship semantics:
#
#     add_*    POST   /libraries/:id/relationships/:type
#              Adds the specified resources — existing resources are kept.
#              Use for incremental additions.
#
#     remove_* DELETE /libraries/:id/relationships/:type
#              Removes only the specified resources — others are kept.
#              Use for targeted removals.
#
#     set_*    PATCH  /libraries/:id/relationships/:type
#              Replaces the ENTIRE list with exactly what you send.
#              Anything not included is removed. Use with caution —
#              passing an empty array removes all resources of that type.
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

      # Maps user-facing library states to the Reactor API transition actions.
      TRANSITION_ACTIONS = {
        'development' => 'develop',
        'develop' => 'develop',
        'submitted' => 'submit',
        'submit' => 'submit',
        'approved' => 'approve',
        'approve' => 'approve',
        'rejected' => 'reject',
        'reject' => 'reject',
        'published' => 'publish',
        'publish' => 'publish'
      }.freeze

      # ── List and find ───────────────────────────────────────────

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
        @parser.parse(response['data'], Resources::Library)
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
      # @param library_id [String] Adobe library ID
      # @return [ReactorSDK::Resources::LibraryWithResources]
      # @raise [ReactorSDK::ResourceNotFoundError] if the library does not exist
      #
      def find_with_resources(library_id)
        response = @connection.get(
          "/libraries/#{library_id}",
          params: { 'include' => 'rules,data_elements,extensions' }
        )
        build_library_with_resources(response)
      end

      # ── Create ──────────────────────────────────────────────────

      ##
      # Creates a new library within a property.
      #
      # @param property_id [String] Adobe property ID
      # @param name        [String] Display name for the library
      # @return [ReactorSDK::Resources::Library] The newly created library
      # @raise [ReactorSDK::UnprocessableEntityError] if attributes are invalid
      #
      def create(property_id:, name:)
        payload  = build_payload('libraries', { name: name })
        response = @connection.post("/properties/#{property_id}/libraries", payload)
        @parser.parse(response['data'], Resources::Library)
      end

      ##
      # Updates a library's attributes.
      #
      # @param library_id [String]
      # @param attributes [Hash]
      # @return [ReactorSDK::Resources::Library]
      #
      def update(library_id, attributes)
        update_resource(
          "/libraries/#{library_id}",
          library_id,
          'libraries',
          Resources::Library,
          attributes: attributes
        )
      end

      ##
      # Deletes a library.
      #
      # @param library_id [String]
      # @return [nil]
      #
      def delete(library_id)
        delete_resource("/libraries/#{library_id}")
      end

      ##
      # Retrieves the property that owns a library.
      #
      # @param library_id [String]
      # @return [ReactorSDK::Resources::Property]
      #
      def property(library_id)
        fetch_resource("/libraries/#{library_id}/property", Resources::Property)
      end

      # ── Rules relationship management ───────────────────────────

      ##
      # Adds rules to a library.
      # Existing rules in the library are preserved — only the specified
      # rules are added.
      #
      # @param library_id [String]        Adobe library ID
      # @param rule_ids   [Array<String>] Adobe rule IDs to add
      # @return [nil]
      # @raise [ReactorSDK::ResourceNotFoundError] if the library does not exist
      #
      def add_rules(library_id, rule_ids)
        payload = build_relationship_payload('rules', rule_ids)
        @connection.post("/libraries/#{library_id}/relationships/rules", payload)
        nil
      end

      ##
      # Removes specific rules from a library.
      # Only the specified rules are removed — other rules are preserved.
      #
      # @param library_id [String]        Adobe library ID
      # @param rule_ids   [Array<String>] Adobe rule IDs to remove
      # @return [nil]
      # @raise [ReactorSDK::ResourceNotFoundError] if the library does not exist
      #
      def remove_rules(library_id, rule_ids)
        payload = build_relationship_payload('rules', rule_ids)
        @connection.delete_relationship("/libraries/#{library_id}/relationships/rules", payload)
        nil
      end

      ##
      # Replaces the entire rules list for a library.
      # Any rule currently in the library that is NOT in rule_ids is removed.
      # Passing an empty array removes all rules from the library.
      #
      # Use with caution — this is a destructive operation.
      # Prefer add_rules and remove_rules for incremental changes.
      #
      # @param library_id [String]        Adobe library ID
      # @param rule_ids   [Array<String>] Complete new list of Adobe rule IDs
      # @return [nil]
      # @raise [ReactorSDK::ResourceNotFoundError] if the library does not exist
      #
      def set_rules(library_id, rule_ids)
        payload = build_relationship_payload('rules', rule_ids)
        @connection.patch("/libraries/#{library_id}/relationships/rules", payload)
        nil
      end

      ##
      # Lists the rules currently assigned to a library.
      #
      # @param library_id [String]
      # @return [Array<ReactorSDK::Resources::Rule>]
      #
      def rules(library_id)
        list_resources("/libraries/#{library_id}/rules", Resources::Rule)
      end

      ##
      # Retrieves raw rule relationship linkage for a library.
      #
      # @param library_id [String]
      # @return [Hash, Array<Hash>, nil]
      #
      def rule_relationships(library_id)
        fetch_relationship("/libraries/#{library_id}/relationships/rules")
      end

      # ── Data elements relationship management ───────────────────

      ##
      # Adds data elements to a library.
      # Existing data elements in the library are preserved.
      #
      # @param library_id       [String]        Adobe library ID
      # @param data_element_ids [Array<String>] Adobe data element IDs to add
      # @return [nil]
      # @raise [ReactorSDK::ResourceNotFoundError] if the library does not exist
      #
      def add_data_elements(library_id, data_element_ids)
        payload = build_relationship_payload('data_elements', data_element_ids)
        @connection.post("/libraries/#{library_id}/relationships/data_elements", payload)
        nil
      end

      ##
      # Removes specific data elements from a library.
      # Only the specified data elements are removed — others are preserved.
      #
      # @param library_id       [String]        Adobe library ID
      # @param data_element_ids [Array<String>] Adobe data element IDs to remove
      # @return [nil]
      # @raise [ReactorSDK::ResourceNotFoundError] if the library does not exist
      #
      def remove_data_elements(library_id, data_element_ids)
        payload = build_relationship_payload('data_elements', data_element_ids)
        @connection.delete_relationship("/libraries/#{library_id}/relationships/data_elements", payload)
        nil
      end

      ##
      # Replaces the entire data elements list for a library.
      # Any data element currently in the library that is NOT in
      # data_element_ids is removed.
      # Passing an empty array removes all data elements from the library.
      #
      # Use with caution — this is a destructive operation.
      #
      # @param library_id       [String]        Adobe library ID
      # @param data_element_ids [Array<String>] Complete new list of data element IDs
      # @return [nil]
      # @raise [ReactorSDK::ResourceNotFoundError] if the library does not exist
      #
      def set_data_elements(library_id, data_element_ids)
        payload = build_relationship_payload('data_elements', data_element_ids)
        @connection.patch("/libraries/#{library_id}/relationships/data_elements", payload)
        nil
      end

      ##
      # Lists the data elements currently assigned to a library.
      #
      # @param library_id [String]
      # @return [Array<ReactorSDK::Resources::DataElement>]
      #
      def data_elements(library_id)
        list_resources("/libraries/#{library_id}/data_elements", Resources::DataElement)
      end

      ##
      # Retrieves raw data element relationship linkage for a library.
      #
      # @param library_id [String]
      # @return [Hash, Array<Hash>, nil]
      #
      def data_element_relationships(library_id)
        fetch_relationship("/libraries/#{library_id}/relationships/data_elements")
      end

      # ── Extensions relationship management ──────────────────────

      ##
      # Adds extensions to a library.
      # Existing extensions in the library are preserved.
      #
      # @param library_id    [String]        Adobe library ID
      # @param extension_ids [Array<String>] Adobe extension IDs to add
      # @return [nil]
      # @raise [ReactorSDK::ResourceNotFoundError] if the library does not exist
      #
      def add_extensions(library_id, extension_ids)
        payload = build_relationship_payload('extensions', extension_ids)
        @connection.post("/libraries/#{library_id}/relationships/extensions", payload)
        nil
      end

      ##
      # Removes specific extensions from a library.
      # Only the specified extensions are removed — others are preserved.
      #
      # @param library_id    [String]        Adobe library ID
      # @param extension_ids [Array<String>] Adobe extension IDs to remove
      # @return [nil]
      # @raise [ReactorSDK::ResourceNotFoundError] if the library does not exist
      #
      def remove_extensions(library_id, extension_ids)
        payload = build_relationship_payload('extensions', extension_ids)
        @connection.delete_relationship("/libraries/#{library_id}/relationships/extensions", payload)
        nil
      end

      ##
      # Replaces the entire extensions list for a library.
      # Any extension currently in the library that is NOT in extension_ids
      # is removed. Passing an empty array removes all extensions.
      #
      # Use with caution — this is a destructive operation.
      #
      # @param library_id    [String]        Adobe library ID
      # @param extension_ids [Array<String>] Complete new list of extension IDs
      # @return [nil]
      # @raise [ReactorSDK::ResourceNotFoundError] if the library does not exist
      #
      def set_extensions(library_id, extension_ids)
        payload = build_relationship_payload('extensions', extension_ids)
        @connection.patch("/libraries/#{library_id}/relationships/extensions", payload)
        nil
      end

      ##
      # Lists the extensions currently assigned to a library.
      #
      # @param library_id [String]
      # @return [Array<ReactorSDK::Resources::Extension>]
      #
      def extensions(library_id)
        list_resources("/libraries/#{library_id}/extensions", Resources::Extension)
      end

      ##
      # Retrieves raw extension relationship linkage for a library.
      #
      # @param library_id [String]
      # @return [Hash, Array<Hash>, nil]
      #
      def extension_relationships(library_id)
        fetch_relationship("/libraries/#{library_id}/relationships/extensions")
      end

      # ── Environment assignment ──────────────────────────────────

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
        payload = { data: { id: environment_id, type: 'environments' } }
        @connection.patch("/libraries/#{library_id}/relationships/environment", payload)
        nil
      end

      ##
      # Retrieves the environment currently assigned to a library.
      #
      # @param library_id [String]
      # @return [ReactorSDK::Resources::Environment]
      #
      def environment(library_id)
        fetch_resource("/libraries/#{library_id}/environment", Resources::Environment)
      end

      ##
      # Retrieves the raw environment relationship for a library.
      #
      # @param library_id [String]
      # @return [Hash, Array<Hash>, nil]
      #
      def environment_relationship(library_id)
        fetch_relationship("/libraries/#{library_id}/relationships/environment")
      end

      ##
      # Removes any assigned environment from a library.
      #
      # @param library_id [String]
      # @return [nil]
      #
      def remove_environment(library_id)
        delete_resource("/libraries/#{library_id}/relationships/environment")
      end

      # ── State machine ───────────────────────────────────────────

      ##
      # Transitions a library to a new state in its workflow.
      #
      # Valid transitions:
      #   development -> submitted -> approved -> published
      #                           -> rejected -> development
      #
      # @param library_id [String] Adobe library ID
      # @param state      [String] Target state to transition to
      # @return [ReactorSDK::Resources::Library] The updated library
      # @raise [ReactorSDK::UnprocessableEntityError] if the transition is invalid
      #
      def transition(library_id, state:)
        payload = {
          data: {
            id: library_id,
            type: 'libraries',
            meta: { action: normalize_transition_action(state) }
          }
        }
        response = @connection.patch("/libraries/#{library_id}", payload)
        @parser.parse(response['data'], Resources::Library)
      end

      # ── Build ───────────────────────────────────────────────────

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
        @parser.parse(response['data'], Resources::Build)
      end

      ##
      # Retrieves the immediate upstream library configured for a library.
      #
      # @param library_id [String]
      # @return [ReactorSDK::Resources::Library]
      #
      def upstream_library(library_id)
        fetch_resource("/libraries/#{library_id}/upstream_library", Resources::Library)
      end

      ##
      # Lists notes attached to a library.
      #
      # @param library_id [String]
      # @return [Array<ReactorSDK::Resources::Note>]
      #
      def list_notes(library_id)
        list_notes_for_path("/libraries/#{library_id}/notes")
      end

      ##
      # Creates a note on a library.
      #
      # @param library_id [String]
      # @param text [String]
      # @return [ReactorSDK::Resources::Note]
      #
      def create_note(library_id, text)
        create_note_for_path("/libraries/#{library_id}/notes", text)
      end

      # ── Upstream resolution ─────────────────────────────────────

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
      # @param library_id  [String] Adobe library ID of the target library
      # @param property_id [String] Adobe property ID
      # @return [Array<ReactorSDK::Resources::Library>] Upstream libraries, nearest first
      # @raise [ReactorSDK::ResourceNotFoundError] if either resource does not exist
      #
      def upstream_libraries(library_id, property_id:)
        find(library_id)
        target_stage = fetch_library_stage(library_id)

        return [] if target_stage.nil?
        return [] if target_stage == 'production'

        upstream_stages = stages_above(target_stage)
        all_libraries   = list_for_property(property_id)

        upstream_stages.filter_map do |stage|
          all_libraries.find do |lib|
            fetch_library_stage(lib.id) == stage
          end
        end
      end

      private

      ##
      # Builds a LibraryWithResources from a full API response that includes
      # rules, data_elements, and extensions in the included array.
      #
      # @param response [Hash] Full JSON:API response from the API
      # @return [ReactorSDK::Resources::LibraryWithResources]
      #
      def build_library_with_resources(response)
        data     = response.fetch('data')
        included = Array(response['included'])

        included_by_type = included.group_by { |r| r['type'] }

        Resources::LibraryWithResources.new(
          id: data.fetch('id'),
          type: data.fetch('type'),
          attributes: data.fetch('attributes', {}),
          meta: data.fetch('meta', {}),
          included_resources: {
            'rules' => included_by_type.fetch('rules', []),
            'data_elements' => included_by_type.fetch('data_elements', []),
            'extensions' => included_by_type.fetch('extensions', [])
          }
        )
      end

      ##
      # Fetches the environment stage for a library by following its
      # environment relationship.
      #
      # @param library_id [String] Adobe library ID
      # @return [String, nil] Stage ("development", "staging", "production") or nil
      #
      def fetch_library_stage(library_id)
        env_rel = @connection.get("/libraries/#{library_id}/relationships/environment")
        env_id  = env_rel&.dig('data', 'id')
        return nil unless env_id

        env_response = @connection.get("/environments/#{env_id}")
        env_response&.dig('data', 'attributes', 'stage')
      end

      ##
      # Returns the stages upstream of the given stage, nearest first.
      #
      # @param stage [String] Current stage
      # @return [Array<String>] Upstream stages in order
      #
      def stages_above(stage)
        current_index = UPSTREAM_STAGE_ORDER.index(stage)
        return [] if current_index.nil?

        UPSTREAM_STAGE_ORDER[(current_index + 1)..]
      end

      ##
      # Converts a library state or action alias into the API's expected action.
      #
      # @param state [String, Symbol]
      # @return [String]
      # @raise [ArgumentError] if the transition is unknown
      #
      def normalize_transition_action(state)
        TRANSITION_ACTIONS.fetch(state.to_s) do
          valid = TRANSITION_ACTIONS.keys.uniq.sort.join(', ')
          raise ArgumentError, "Unknown library transition: #{state.inspect}. Expected one of: #{valid}"
        end
      end
    end
  end
end
