# frozen_string_literal: true

##
# @file endpoints/extensions.rb
# @description Endpoint group for Adobe Launch Extension resources.
#
#   Extensions provide the delegates (conditions, actions, data element
#   types) available within a property. The Core extension is always
#   present. Third-party extensions are installed separately.
#
#   Important: extensions must be revised before they can be added to
#   a library. Call revise(extension_id) before libraries.add_extensions.
#
# @domain Endpoints
# @see https://developer.adobe.com/experience-platform/documentation/tags/api/endpoints/extensions/
#

module ReactorSDK
  module Endpoints
    class Extensions < BaseEndpoint
      ##
      # Lists all extensions installed in a given property.
      # Follows pagination automatically — returns all extensions.
      #
      # @param property_id [String] Adobe property ID
      # @return [Array<ReactorSDK::Resources::Extension>]
      # @raise [ReactorSDK::ResourceNotFoundError] if the property does not exist
      #
      def list_for_property(property_id)
        records = @paginator.all("/properties/#{property_id}/extensions")
        records.map { |r| @parser.parse(r, Resources::Extension) }
      end

      ##
      # Retrieves a single extension by its Adobe ID.
      #
      # @param extension_id [String] Adobe extension ID (format: "EX" + hex string)
      # @return [ReactorSDK::Resources::Extension]
      # @raise [ReactorSDK::ResourceNotFoundError] if the extension does not exist
      #
      def find(extension_id)
        response = @connection.get("/extensions/#{extension_id}")
        @parser.parse(response['data'], Resources::Extension)
      end

      ##
      # Creates an extension within a property.
      #
      # @param property_id [String]
      # @param attributes [Hash]
      # @param relationships [Hash]
      # @return [ReactorSDK::Resources::Extension]
      #
      def create(property_id:, attributes:, relationships:)
        create_resource(
          "/properties/#{property_id}/extensions",
          'extensions',
          Resources::Extension,
          attributes: attributes,
          relationships: relationships
        )
      end

      ##
      # Revises an extension so it can be added to a library.
      #
      # Adobe Launch requires every resource to be explicitly revised before
      # it can be added to a library.
      #
      # Always call revise before libraries.add_extensions.
      #
      # @param extension_id [String] Adobe extension ID
      # @return [ReactorSDK::Resources::Extension] The revised extension
      # @raise [ReactorSDK::ResourceNotFoundError] if the extension does not exist
      #
      def revise(extension_id)
        update_resource(
          "/extensions/#{extension_id}",
          extension_id,
          'extensions',
          Resources::Extension,
          attributes: {},
          meta: { action: 'revise' }
        )
      end

      def delete(extension_id)
        delete_resource("/extensions/#{extension_id}")
      end

      def extension_package(extension_id)
        fetch_resource("/extensions/#{extension_id}/extension_package", Resources::ExtensionPackage)
      end

      def libraries(extension_id)
        list_resources("/extensions/#{extension_id}/libraries", Resources::Library)
      end

      def property(extension_id)
        fetch_resource("/extensions/#{extension_id}/property", Resources::Property)
      end

      def origin(extension_id)
        fetch_resource("/extensions/#{extension_id}/origin", Resources::Extension)
      end

      ##
      # Resolves the extension across the ordered upstream library chain.
      #
      # @param extension_or_id [String, ReactorSDK::Resources::Extension]
      # @param library_id [String] Adobe library ID used as the comparison root
      # @param property_id [String] Adobe property ID containing the library chain
      # @return [ReactorSDK::Resources::UpstreamChain]
      #
      def upstream_chain(extension_or_id, library_id:, property_id:)
        libraries_endpoint.upstream_chain_for_resource(
          extension_or_id,
          library_id: library_id,
          property_id: property_id,
          resource_type: 'extensions'
        )
      end

      ##
      # Fetches the extension from a library-context review snapshot together
      # with dependent resources and normalized review payload.
      #
      # @param extension_id [String]
      # @param library_id [String]
      # @param property_id [String]
      # @return [ReactorSDK::Resources::ComprehensiveExtension]
      #
      def find_comprehensive(extension_id, library_id:, property_id:)
        snapshot = libraries_endpoint.find_snapshot(library_id, property_id: property_id)
        comprehensive = snapshot.comprehensive_resource(extension_id, resource_type: 'extensions')
        unless comprehensive
          raise ReactorSDK::ResourceNotFoundError,
                "Extension #{extension_id} was not found in library #{library_id}"
        end

        comprehensive
      end

      ##
      # Resolves the extension across the ordered upstream chain using
      # snapshot-aware comprehensive review objects.
      #
      # @param extension_or_id [String, ReactorSDK::Resources::Extension]
      # @param library_id [String]
      # @param property_id [String]
      # @return [ReactorSDK::Resources::ComprehensiveUpstreamChain]
      #
      def comprehensive_upstream_chain(extension_or_id, library_id:, property_id:)
        libraries_endpoint.comprehensive_upstream_chain_for_resource(
          extension_or_id,
          library_id: library_id,
          property_id: property_id,
          resource_type: 'extensions'
        )
      end

      def list_notes(extension_id)
        list_notes_for_path("/extensions/#{extension_id}/notes")
      end

      def create_note(extension_id, text)
        create_note_for_path("/extensions/#{extension_id}/notes", text)
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
