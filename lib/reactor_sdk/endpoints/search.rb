# frozen_string_literal: true

module ReactorSDK
  module Endpoints
    class Search < BaseEndpoint
      def perform(query:, from: nil, size: nil, sort: nil, resource_types: nil)
        payload = { query: query }
        payload[:from] = from unless from.nil?
        payload[:size] = size unless size.nil?
        payload[:sort] = sort unless sort.nil?
        payload[:resource_types] = resource_types unless resource_types.nil?

        response = @connection.post('/search', payload)
        Resources::SearchResults.new(
          results: @parser.parse_many_auto(response['data']),
          meta: response.fetch('meta', {})
        )
      end

      alias query perform
    end
  end
end
