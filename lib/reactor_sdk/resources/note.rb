# frozen_string_literal: true

##
# @file resources/note.rb
# @description Represents an Adobe Launch Note resource.
#
#   Notes are textual annotations attached to notable Launch resources such
#   as rules, data elements, libraries, properties, extensions, and rule
#   components.
#
# @domain Resources
#

module ReactorSDK
  module Resources
    class Note < BaseResource
      # @return [String] Note body text
      attribute :text

      # @return [String] Display name of the note author
      attribute :author_display_name

      # @return [String] Email of the note author
      attribute :author_email

      # @return [String] ISO8601 timestamp when the note was created
      attribute :created_at

      ##
      # @return [String] Human-readable representation
      #
      def inspect
        "#<ReactorSDK::Resources::Note id=#{id.inspect} text=#{text.inspect}>"
      end
    end
  end
end
