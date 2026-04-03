# frozen_string_literal: true

##
# @file endpoints/rules.rb
# @description Endpoint group for Adobe Launch Rule resources.
#
#   Rules define the logic Adobe Launch executes. They consist of
#   conditions (when to run) and actions (what to do). Rules belong
#   to a property and are versioned — the revisions endpoint provides
#   point-in-time snapshots used by the diff engine.
#
#   Important: rules must be revised before they can be added to a library.
#   Call revise(rule_id) after creating or updating a rule.
#
# @domain Endpoints
# @see https://developer.adobe.com/experience-platform/documentation/tags/api/endpoints/rules/
#

module ReactorSDK
  module Endpoints
    class Rules < BaseEndpoint
      ##
      # Lists all rules for a given property.
      # Follows pagination automatically — returns all rules.
      #
      # @param property_id [String] Adobe property ID
      # @return [Array<ReactorSDK::Resources::Rule>]
      # @raise [ReactorSDK::ResourceNotFoundError] if the property does not exist
      #
      def list_for_property(property_id)
        list_resources("/properties/#{property_id}/rules", Resources::Rule)
      end

      ##
      # Retrieves a single rule by its Adobe ID.
      #
      # @param rule_id [String] Adobe rule ID (format: "RL" + hex string)
      # @return [ReactorSDK::Resources::Rule]
      # @raise [ReactorSDK::ResourceNotFoundError] if the rule does not exist
      #
      def find(rule_id)
        fetch_resource("/rules/#{rule_id}", Resources::Rule)
      end

      ##
      # Retrieves the property that owns a rule.
      #
      # @param rule_id [String] Adobe rule ID
      # @return [ReactorSDK::Resources::Property]
      #
      def property(rule_id)
        fetch_resource("/rules/#{rule_id}/property", Resources::Property)
      end

      ##
      # Lists the libraries containing a rule.
      #
      # @param rule_id [String] Adobe rule ID
      # @return [Array<ReactorSDK::Resources::Library>]
      #
      def libraries(rule_id)
        list_resources("/rules/#{rule_id}/libraries", Resources::Library)
      end

      ##
      # Resolves the rule across the ordered upstream library chain.
      #
      # This is a convenience wrapper around Libraries#upstream_chain_for_resource
      # so rule workflows can stay resource-centric at the call site.
      #
      # @param rule_or_id [String, ReactorSDK::Resources::Rule]
      # @param library_id [String] Adobe library ID used as the comparison root
      # @param property_id [String] Adobe property ID containing the library chain
      # @return [ReactorSDK::Resources::UpstreamChain]
      #
      def upstream_chain(rule_or_id, library_id:, property_id:)
        libraries_endpoint.upstream_chain_for_resource(
          rule_or_id,
          library_id: library_id,
          property_id: property_id,
          resource_type: 'rules'
        )
      end

      ##
      # Fetches the rule from a library-context review snapshot together with
      # its associated rule components and normalized review payload.
      #
      # @param rule_id [String]
      # @param library_id [String]
      # @param property_id [String]
      # @return [ReactorSDK::Resources::ComprehensiveRule]
      #
      def find_comprehensive(rule_id, library_id:, property_id:)
        snapshot = libraries_endpoint.find_snapshot(library_id, property_id: property_id)
        comprehensive = snapshot.comprehensive_resource(rule_id, resource_type: 'rules')
        unless comprehensive
          raise ReactorSDK::ResourceNotFoundError,
                "Rule #{rule_id} was not found in library #{library_id}"
        end

        comprehensive
      end

      ##
      # Resolves the rule across the ordered upstream chain and returns
      # comprehensive review objects for the target and upstream entries.
      #
      # @param rule_or_id [String, ReactorSDK::Resources::Rule]
      # @param library_id [String]
      # @param property_id [String]
      # @return [ReactorSDK::Resources::ComprehensiveUpstreamChain]
      #
      def comprehensive_upstream_chain(rule_or_id, library_id:, property_id:)
        libraries_endpoint.comprehensive_upstream_chain_for_resource(
          rule_or_id,
          library_id: library_id,
          property_id: property_id,
          resource_type: 'rules'
        )
      end

      ##
      # Retrieves the origin revision head for a rule.
      #
      # @param rule_id [String] Adobe rule ID
      # @return [ReactorSDK::Resources::Rule]
      #
      def origin(rule_id)
        fetch_resource("/rules/#{rule_id}/origin", Resources::Rule)
      end

      ##
      # Creates a new rule within a property.
      #
      # @param property_id [String]  Adobe property ID
      # @param name        [String]  Display name for the rule
      # @param enabled     [Boolean] Whether the rule is enabled (default: true)
      # @return [ReactorSDK::Resources::Rule] The newly created rule
      # @raise [ReactorSDK::UnprocessableEntityError] if attributes are invalid
      #
      def create(property_id:, name:, enabled: true)
        create_resource(
          "/properties/#{property_id}/rules",
          'rules',
          Resources::Rule,
          attributes: { name: name, enabled: enabled }
        )
      end

      ##
      # Updates an existing rule.
      #
      # @param rule_id    [String] Adobe rule ID
      # @param attributes [Hash]   Fields to update (e.g. { name: "New Name" })
      # @return [ReactorSDK::Resources::Rule] The updated rule
      # @raise [ReactorSDK::ResourceNotFoundError] if the rule does not exist
      #
      def update(rule_id, attributes)
        update_resource("/rules/#{rule_id}", rule_id, 'rules', Resources::Rule, attributes: attributes)
      end

      ##
      # Revises a rule so it can be added to a library.
      #
      # Adobe Launch requires every resource to be explicitly revised before
      # it can be added to a library. A newly created or updated rule cannot
      # be added to a library until revised.
      #
      # Always call revise after create or update, before libraries.add_rules.
      #
      # @param rule_id [String] Adobe rule ID
      # @return [ReactorSDK::Resources::Rule] The revised rule
      # @raise [ReactorSDK::ResourceNotFoundError] if the rule does not exist
      #
      def revise(rule_id)
        update_resource(
          "/rules/#{rule_id}",
          rule_id,
          'rules',
          Resources::Rule,
          attributes: {},
          meta: { action: 'revise' }
        )
      end

      ##
      # Deletes a rule permanently.
      #
      # @param rule_id [String] Adobe rule ID
      # @return [nil]
      # @raise [ReactorSDK::ResourceNotFoundError] if the rule does not exist
      #
      def delete(rule_id)
        delete_resource("/rules/#{rule_id}")
      end

      ##
      # Creates a note on a rule.
      #
      # @param rule_id [String] Adobe rule ID
      # @param text    [String] Note body text
      # @return [ReactorSDK::Resources::Note]
      #
      def create_note(rule_id, text)
        create_note_for_path("/rules/#{rule_id}/notes", text)
      end

      ##
      # Lists notes attached directly to a rule.
      #
      # @param rule_id [String]
      # @return [Array<ReactorSDK::Resources::Note>]
      #
      def list_notes(rule_id)
        list_notes_for_path("/rules/#{rule_id}/notes")
      end

      ##
      # Lists rule components associated with the rule's component notes route.
      #
      # @param rule_id [String]
      # @return [Array<ReactorSDK::Resources::RuleComponent>]
      #
      def rule_component_notes(rule_id)
        list_resources("/rules/#{rule_id}/rule_component_notes", Resources::RuleComponent)
      end

      private

      def libraries_endpoint
        @libraries_endpoint ||= Endpoints::Libraries.new(
          connection: @connection,
          paginator: @paginator,
          parser: @parser
        )
      end
    end
  end
end
