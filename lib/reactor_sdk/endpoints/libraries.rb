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
      # Calls GET /libraries/:id?include=rules,data_elements,extensions.
      # When Adobe returns the JSON:API included payload, the SDK uses it
      # directly. When Adobe omits included, the SDK falls back to the
      # related /rules, /data_elements, and /extensions endpoints so the
      # result still reflects the library's directly attached resources.
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
        build_library_with_resources(response, library_id: library_id)
      end

      ##
      # Fetches the effective library snapshot used by Launch review flows.
      #
      # Effective snapshots include both:
      #   - resources directly attached to the target library
      #   - inherited upstream resources when the target library does not
      #     override them
      #
      # Rule components are resolved against the effective rule revision so
      # inherited rules carry the point-in-time component set a reviewer
      # would see in Adobe Launch.
      #
      # The returned object is intentionally built fresh on each call so
      # review workflows never read stale snapshot state after writes.
      #
      # @param library_id [String] Adobe library ID
      # @param property_id [String] Adobe property ID containing the library
      # @return [ReactorSDK::Resources::LibrarySnapshot]
      #
      def find_snapshot(library_id, property_id:)
        fetch_effective_snapshot(library_id, property_id: property_id, cache: {})
      end

      ##
      # Fetches the direct snapshot for a library without inheriting any
      # upstream resources.
      #
      # This preserves the pre-1.0 direct-only snapshot behavior for callers
      # that need to inspect exactly what is attached to one library.
      #
      # @param library_id [String] Adobe library ID
      # @param property_id [String] Adobe property ID containing the library
      # @return [ReactorSDK::Resources::LibrarySnapshot]
      #
      def find_direct_snapshot(library_id, property_id:)
        direct_snapshot_builder.build(library_id, property_id: property_id)
      end

      ##
      # Compares two libraries and returns per-resource review details that
      # can be passed directly into Changeset-style diff tooling.
      #
      # The first library is treated as the current version and the second
      # library is treated as the baseline version. Changeset-style document
      # helpers therefore map baseline content to old_content and current
      # content to new_content.
      #
      # @param current_library_id [String] Library being reviewed
      # @param baseline_library_id [String] Library used as the comparison baseline
      # @param property_id [String] Adobe property ID containing both libraries
      # @return [ReactorSDK::Resources::LibraryComparison]
      #
      def compare(current_library_id, baseline_library_id:, property_id:)
        snapshot_cache = {}

        comparison_builder.build(
          current_library_id,
          baseline_library_id: baseline_library_id,
          property_id: property_id,
          current_snapshot: fetch_effective_snapshot(current_library_id, property_id: property_id, cache: snapshot_cache),
          baseline_snapshot: fetch_effective_snapshot(
            baseline_library_id,
            property_id: property_id,
            cache: snapshot_cache
          )
        )
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

      ##
      # Resolves a single resource across the ordered upstream library chain.
      #
      # This is the resource-level convenience wrapper built on top of
      # upstream_libraries and find_with_resources. It allows callers to ask
      # for upstream information directly from a rule, data element, or
      # extension ID without hand-rolling the traversal loop.
      #
      # The returned UpstreamChain object includes:
      #   - the target library context
      #   - the target resource and target revision_id when present
      #   - one UpstreamChainEntry per upstream library, nearest first
      #
      # @param resource_or_id [String, ReactorSDK::Resources::BaseResource]
      # @param library_id     [String] Adobe library ID used as the comparison root
      # @param property_id    [String] Adobe property ID containing the library chain
      # @param resource_type  [String, nil] Optional JSON:API type hint
      # @return [ReactorSDK::Resources::UpstreamChain]
      #
      def upstream_chain_for_resource(resource_or_id, library_id:, property_id:, resource_type: nil)
        resource_id = extract_resource_id(resource_or_id)
        target_library = find_with_resources(library_id)
        target_resource = target_library.all_resources.find { |resource| resource.id == resource_id }
        target_revision_id = target_library.resource_index[resource_id]

        entries = upstream_libraries(library_id, property_id: property_id).map do |library|
          build_upstream_chain_entry(library, resource_id)
        end

        Resources::UpstreamChain.new(
          resource_id: resource_id,
          resource_type: resource_type || extract_resource_type(resource_or_id) || target_resource&.type,
          property_id: property_id,
          target_library_id: library_id,
          target_resource: target_resource,
          target_revision_id: target_revision_id,
          entries: entries
        )
      end

      ##
      # Resolves a resource across the ordered upstream library chain using
      # snapshot-aware comprehensive resource wrappers.
      #
      # @param resource_or_id [String, ReactorSDK::Resources::BaseResource]
      # @param library_id [String]
      # @param property_id [String]
      # @param resource_type [String, nil]
      # @return [ReactorSDK::Resources::ComprehensiveUpstreamChain]
      #
      def comprehensive_upstream_chain_for_resource(resource_or_id, library_id:, property_id:, resource_type: nil)
        resource_id = extract_resource_id(resource_or_id)
        snapshot_cache = {}
        target_context = resolve_comprehensive_target_context(
          resource_or_id,
          resource_id,
          library_id,
          property_id,
          snapshot_cache,
          resource_type
        )

        build_comprehensive_upstream_chain(
          resource_id,
          library_id: library_id,
          property_id: property_id,
          target_context: target_context,
          snapshot_cache: snapshot_cache
        )
      end

      private

      ##
      # Builds a LibraryWithResources from a full API response that includes
      # rules, data_elements, and extensions in the included array.
      #
      # @param response [Hash] Full JSON:API response from the API
      # @return [ReactorSDK::Resources::LibraryWithResources]
      #
      def build_library_with_resources(response, library_id: nil)
        data     = fetch_hash_value(response, 'data')
        included = Array(hash_value(response, 'included', []))

        included_resources = if included.empty? && library_id
                               fallback_included_resources(library_id)
                             else
                               resources_grouped_by_type(included)
                             end

        Resources::LibraryWithResources.new(
          id: fetch_hash_value(data, 'id'),
          type: fetch_hash_value(data, 'type'),
          attributes: hash_value(data, 'attributes', {}),
          meta: hash_value(data, 'meta', {}),
          relationships: hash_value(data, 'relationships', {}),
          included_resources: included_resources
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

      def fetch_hash_value(hash, key)
        return hash.fetch(key) if hash.key?(key)

        alternate_key = key.is_a?(String) ? key.to_sym : key.to_s
        return hash.fetch(alternate_key) if hash.key?(alternate_key)

        raise KeyError, "key not found: #{key.inspect}"
      end

      def hash_value(hash, key, default = nil)
        return default unless hash.respond_to?(:key?)
        return hash[key] if hash.key?(key)

        alternate_key = key.is_a?(String) ? key.to_sym : key.to_s
        return hash[alternate_key] if hash.key?(alternate_key)

        default
      end

      def fallback_included_resources(library_id)
        {
          'rules' => serialize_resources(rules(library_id)),
          'data_elements' => serialize_resources(data_elements(library_id)),
          'extensions' => serialize_resources(extensions(library_id))
        }
      end

      def serialize_resources(resources)
        Array(resources).map(&:to_h)
      end

      def resources_grouped_by_type(resources)
        included_by_type = resources.group_by { |resource| hash_value(resource, 'type')&.to_s }

        {
          'rules' => included_by_type.fetch('rules', []),
          'data_elements' => included_by_type.fetch('data_elements', []),
          'extensions' => included_by_type.fetch('extensions', [])
        }
      end

      ##
      # Builds one upstream-chain entry for a specific library and resource ID.
      #
      # @param library     [ReactorSDK::Resources::Library]
      # @param resource_id [String]
      # @return [ReactorSDK::Resources::UpstreamChainEntry]
      #
      def build_upstream_chain_entry(library, resource_id)
        library_with_resources = find_with_resources(library.id)
        matched_resource = library_with_resources.all_resources.find { |resource| resource.id == resource_id }
        revision_id = library_with_resources.resource_index[resource_id]
        revision = revision_id ? revisions_endpoint.find(revision_id) : nil

        Resources::UpstreamChainEntry.new(
          library: library,
          stage: fetch_library_stage(library.id),
          resource: matched_resource,
          revision_id: revision_id,
          revision: revision
        )
      end

      def build_comprehensive_upstream_chain_entry(library, resource_id, property_id:, resource_type:, snapshot_cache:)
        snapshot = fetch_effective_snapshot(library.id, property_id: property_id, cache: snapshot_cache)
        resource = snapshot.find_resource(resource_id)
        revision_id = snapshot.resource_revision_id(resource_id)
        revision = revision_id ? revisions_endpoint.find(revision_id) : nil

        Resources::ComprehensiveUpstreamChainEntry.new(
          library: library,
          stage: fetch_library_stage(library.id),
          resource: resource,
          revision_id: revision_id,
          revision: revision,
          comprehensive_resource: snapshot.comprehensive_resource(resource_id, resource_type: resource_type)
        )
      end

      def resolve_comprehensive_target_context(
        resource_or_id,
        resource_id,
        library_id,
        property_id,
        snapshot_cache,
        resource_type
      )
        snapshot = fetch_effective_snapshot(library_id, property_id: property_id, cache: snapshot_cache)
        build_comprehensive_target_context(resource_or_id, resource_id, snapshot, resource_type)
      end

      def build_comprehensive_target_context(resource_or_id, resource_id, snapshot, resource_type)
        resource = snapshot.find_resource(resource_id)
        resolved_resource_type = resource_type || extract_resource_type(resource_or_id) || resource&.type

        {
          resource: resource,
          resource_type: resolved_resource_type,
          revision_id: snapshot.resource_revision_id(resource_id),
          comprehensive_resource: snapshot.comprehensive_resource(resource_id, resource_type: resolved_resource_type)
        }
      end

      def build_comprehensive_upstream_chain(resource_id, library_id:, property_id:, target_context:, snapshot_cache:)
        Resources::ComprehensiveUpstreamChain.new(
          resource_id: resource_id,
          resource_type: target_context.fetch(:resource_type),
          property_id: property_id,
          target_library_id: library_id,
          target_resource: target_context.fetch(:resource),
          target_revision_id: target_context.fetch(:revision_id),
          target_comprehensive_resource: target_context.fetch(:comprehensive_resource),
          entries: build_comprehensive_upstream_entries(
            library_id,
            property_id,
            resource_id,
            target_context.fetch(:resource_type),
            snapshot_cache
          )
        )
      end

      def build_comprehensive_upstream_entries(library_id, property_id, resource_id, resource_type, snapshot_cache)
        upstream_libraries(library_id, property_id: property_id).map do |library|
          build_comprehensive_upstream_chain_entry(
            library,
            resource_id,
            property_id: property_id,
            resource_type: resource_type,
            snapshot_cache: snapshot_cache
          )
        end
      end

      def fetch_effective_snapshot(library_id, property_id:, cache:)
        cache.fetch(effective_snapshot_cache_key(library_id, property_id)) do
          cache[effective_snapshot_cache_key(library_id, property_id)] = build_effective_snapshot(
            library_id,
            property_id: property_id,
            cache: cache
          )
        end
      end

      def build_effective_snapshot(library_id, property_id:, cache:)
        direct_snapshot = fetch_direct_snapshot(library_id, property_id: property_id, cache: cache)
        inherited_library = upstream_libraries(library_id, property_id: property_id).first
        return direct_snapshot if inherited_library.nil?

        merge_snapshots(
          direct_snapshot,
          fetch_effective_snapshot(inherited_library.id, property_id: property_id, cache: cache)
        )
      end

      def merge_snapshots(direct_snapshot, inherited_snapshot)
        Resources::LibrarySnapshot.new(
          property_id: direct_snapshot.property_id,
          library: build_merged_library(direct_snapshot, inherited_snapshot),
          rule_components_by_rule_id: merge_rule_component_index(direct_snapshot, inherited_snapshot)
        )
      end

      def build_merged_library(direct_snapshot, inherited_snapshot)
        library = direct_snapshot.library

        Resources::LibraryWithResources.new(
          id: library.id,
          type: library.type,
          attributes: library.attributes,
          meta: library.meta,
          relationships: library.relationships,
          included_resources: {
            'rules' => serialize_resources(merge_resource_lists(direct_snapshot.rules, inherited_snapshot.rules)),
            'data_elements' => serialize_resources(
              merge_resource_lists(direct_snapshot.data_elements, inherited_snapshot.data_elements)
            ),
            'extensions' => serialize_resources(
              merge_resource_lists(direct_snapshot.extensions, inherited_snapshot.extensions)
            )
          }
        )
      end

      def merge_resource_lists(direct_resources, inherited_resources)
        direct_resources = Array(direct_resources)
        direct_resource_ids = direct_resources.each_with_object({}) do |resource, ids|
          ids[resource.id] = true
        end

        direct_resources + Array(inherited_resources).reject { |resource| direct_resource_ids.key?(resource.id) }
      end

      def merge_rule_component_index(direct_snapshot, inherited_snapshot)
        inherited_snapshot.rule_components_by_rule_id.merge(direct_snapshot.rule_components_by_rule_id)
      end

      def fetch_direct_snapshot(library_id, property_id:, cache:)
        cache.fetch(direct_snapshot_cache_key(library_id, property_id)) do
          cache[direct_snapshot_cache_key(library_id, property_id)] = find_direct_snapshot(
            library_id,
            property_id: property_id
          )
        end
      end

      ##
      # Normalizes a resource object or raw resource ID into an Adobe ID string.
      #
      # @param resource_or_id [String, #id]
      # @return [String]
      #
      def extract_resource_id(resource_or_id)
        return resource_or_id.id if resource_or_id.respond_to?(:id)

        resource_or_id
      end

      ##
      # Reads the resource type from a resource object when available.
      #
      # @param resource_or_id [String, #type]
      # @return [String, nil]
      #
      def extract_resource_type(resource_or_id)
        return resource_or_id.type if resource_or_id.respond_to?(:type)

        nil
      end

      ##
      # Builds a lightweight revisions endpoint sharing this endpoint's deps.
      #
      # @return [ReactorSDK::Endpoints::Revisions]
      #
      def revisions_endpoint
        @revisions_endpoint ||= Endpoints::Revisions.new(
          connection: @connection,
          paginator: @paginator,
          parser: @parser
        )
      end

      def rule_components_endpoint
        @rule_components_endpoint ||= Endpoints::RuleComponents.new(
          connection: @connection,
          paginator: @paginator,
          parser: @parser
        )
      end

      def direct_snapshot_builder
        @direct_snapshot_builder ||= ReactorSDK::LibrarySnapshotBuilder.new(
          library_loader: method(:find_with_resources),
          revisions_endpoint: revisions_endpoint,
          rule_components_endpoint: rule_components_endpoint
        )
      end

      def comparison_builder
        @comparison_builder ||= ReactorSDK::LibraryComparisonBuilder.new(
          snapshot_loader: method(:find_snapshot)
        )
      end

      def direct_snapshot_cache_key(library_id, property_id)
        "direct:#{property_id}:#{library_id}"
      end

      def effective_snapshot_cache_key(library_id, property_id)
        "effective:#{property_id}:#{library_id}"
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
