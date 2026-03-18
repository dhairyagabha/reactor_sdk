# frozen_string_literal: true

##
# @file resources/library.rb
# @description Represents an Adobe Launch Library resource.
#
#   A library is a collection of rules, data elements, and extensions
#   that gets built into a deployable JavaScript bundle. Libraries move
#   through a state machine: development -> submitted -> approved ->
#   rejected -> published. Each library is assigned to one environment.
#
# @domain Resources
# @see https://developer.adobe.com/experience-platform/documentation/tags/api/endpoints/libraries/
#

module ReactorSDK
  module Resources
    class Library < BaseResource
      # @return [String] Display name of the library
      attribute :name

      # @return [String] Current state of the library in its workflow
      #   One of: "development", "submitted", "approved", "rejected", "published"
      attribute :state

      # @return [Boolean] Whether the library has been published
      attribute :published, as: :boolean

      # @return [String] ISO8601 timestamp when the library was created
      attribute :created_at

      # @return [String] ISO8601 timestamp when the library was last updated
      attribute :updated_at

      # @return [String, nil] ISO8601 timestamp when the library was published
      attribute :published_at

      # @return [String, nil] ISO8601 timestamp when the library build completed
      attribute :build_required_detail

      ##
      # Returns true if the library is in a state where it can be built.
      #
      # @return [Boolean]
      #
      def buildable?
        state == 'development'
      end

      ##
      # Returns true if the library has been successfully published.
      #
      # @return [Boolean]
      #
      def published?
        state == 'published'
      end

      ##
      # @return [String] Human-readable representation
      #
      def inspect
        "#<ReactorSDK::Resources::Library id=#{id.inspect} name=#{name.inspect} state=#{state.inspect}>"
      end
    end
  end
end
