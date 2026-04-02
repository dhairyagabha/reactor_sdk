# frozen_string_literal: true

##
# @file endpoints/builds.rb
# @description Endpoint group for Adobe Launch Build resources.
#
#   Builds are the compiled output of a library — the JavaScript bundle
#   deployed to an environment. LaunchGuard polls build status after
#   triggering a build to detect success or failure before notifying users.
#
# @domain Endpoints
# @see https://developer.adobe.com/experience-platform/documentation/tags/api/endpoints/builds/
#

module ReactorSDK
  module Endpoints
    class Builds < BaseEndpoint
      ##
      # Retrieves a single build by its Adobe ID.
      # Used to poll build status after a build is triggered.
      #
      # @param build_id [String] Adobe build ID (format: "BL" + hex string)
      # @return [ReactorSDK::Resources::Build]
      # @raise [ReactorSDK::ResourceNotFoundError] if the build does not exist
      #
      def find(build_id)
        response = @connection.get("/builds/#{build_id}")
        @parser.parse(response['data'], Resources::Build)
      end

      ##
      # Lists all builds for a given library.
      # Follows pagination automatically — returns all builds.
      #
      # @param library_id [String] Adobe library ID
      # @return [Array<ReactorSDK::Resources::Build>]
      # @raise [ReactorSDK::ResourceNotFoundError] if the library does not exist
      #
      def list_for_library(library_id)
        records = @paginator.all("/libraries/#{library_id}/builds")
        records.map { |r| @parser.parse(r, Resources::Build) }
      end

      ##
      # Republishes an existing build.
      #
      # @param build_id [String]
      # @return [ReactorSDK::Resources::Build]
      #
      def republish(build_id)
        update_resource(
          "/builds/#{build_id}",
          build_id,
          'builds',
          Resources::Build,
          attributes: {},
          meta: { action: 'republish' }
        )
      end
    end
  end
end
