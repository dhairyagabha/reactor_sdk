# frozen_string_literal: true

##
# @file resources/revision.rb
# @description Represents an Adobe Launch Revision resource.
#
#   Revisions are point-in-time snapshots of any revisable resource
#   (rules, data elements, extensions). They are the foundation of
#   LaunchGuard's diff engine — by comparing two revisions of the same
#   resource the exact field-level changes between versions can be shown.
#
# @domain Resources
# @see https://developer.adobe.com/experience-platform/documentation/tags/api/endpoints/revisions/
#

module ReactorSDK
  module Resources
    class Revision < BaseResource
      # @return [String] ISO8601 timestamp when this revision was created
      attribute :created_at

      # @return [String, nil] The action that created this revision
      #   e.g. "created", "updated", "published"
      attribute :activity_type

      ##
      # @return [String] Human-readable representation
      #
      def inspect
        "#<ReactorSDK::Resources::Revision id=#{id.inspect} created_at=#{created_at.inspect}>"
      end
    end
  end
end
