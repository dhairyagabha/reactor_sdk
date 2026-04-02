# frozen_string_literal: true

module ReactorSDK
  module Endpoints
    class Notes < BaseEndpoint
      def find(note_id)
        fetch_resource("/notes/#{note_id}", Resources::Note)
      end
    end
  end
end
