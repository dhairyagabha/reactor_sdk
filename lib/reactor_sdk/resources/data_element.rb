# frozen_string_literal: true

##
# @file resources/data_element.rb
# @description Represents an Adobe Launch Data Element resource.
#
#   Data elements are the building blocks of Adobe Launch's data layer.
#   They define reusable values that can be referenced in rules and other
#   data elements. Each data element is powered by an extension delegate.
#
# @domain Resources
# @see https://developer.adobe.com/experience-platform/documentation/tags/api/endpoints/data-elements/
#

module ReactorSDK
  module Resources
    class DataElement < BaseResource
      # @return [String] Display name of the data element
      attribute :name

      # @return [Boolean] Whether the data element is enabled
      attribute :enabled, as: :boolean

      # @return [Boolean] Whether to clean text values
      attribute :clean_text, as: :boolean

      # @return [Boolean] Whether to force lowercase
      attribute :force_lower_case, as: :boolean

      # @return [String, nil] Default value when the element returns nil
      attribute :default_value

      # @return [String, nil] How long to cache the value — "none", "pageview",
      #   "session", "visitor", or a number of seconds
      attribute :storage_duration

      # @return [String] Identifies the extension delegate that powers this element
      attribute :delegate_descriptor_id

      # @return [Hash] Configuration settings specific to the delegate
      attribute :settings, default: {}

      # @return [String] ISO8601 timestamp when the element was created
      attribute :created_at

      # @return [String] ISO8601 timestamp when the element was last updated
      attribute :updated_at

      # @return [String, nil] ISO8601 timestamp when the element was last published
      attribute :published_at

      ##
      # @return [String] Human-readable representation
      #
      def inspect
        "#<ReactorSDK::Resources::DataElement id=#{id.inspect} name=#{name.inspect}>"
      end
    end
  end
end
