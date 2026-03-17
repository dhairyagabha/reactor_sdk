# frozen_string_literal: true

##
# @file resources/rule.rb
# @description Represents an Adobe Launch Rule resource.
#
#   Rules define the logic that Adobe Launch executes — they consist
#   of conditions (when to run) and actions (what to do). Rules belong
#   to a property and are versioned via the revisions endpoint.
#
# @domain Resources
# @see https://developer.adobe.com/experience-platform/documentation/tags/api/endpoints/rules/
#

module ReactorSDK
  module Resources
    class Rule < BaseResource
      # @return [String] Display name of the rule
      attribute :name

      # @return [Boolean] Whether the rule is enabled
      attribute :enabled, as: :boolean

      # @return [String] ISO8601 timestamp when the rule was created
      attribute :created_at

      # @return [String] ISO8601 timestamp when the rule was last updated
      attribute :updated_at

      # @return [String, nil] ISO8601 timestamp when the rule was last published
      attribute :published_at

      # @return [String, nil] ISO8601 timestamp when the rule was last revised
      attribute :revised_at

      ##
      # @return [String] Human-readable representation
      #
      def inspect
        "#<ReactorSDK::Resources::Rule id=#{id.inspect} name=#{name.inspect} enabled=#{enabled.inspect}>"
      end
    end
  end
end
