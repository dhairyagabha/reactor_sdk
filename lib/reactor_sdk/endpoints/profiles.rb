# frozen_string_literal: true

module ReactorSDK
  module Endpoints
    class Profiles < BaseEndpoint
      def current
        response = @connection.get('/profile')
        data = response.fetch('data').dup
        data['meta'] = response.fetch('meta', {}).merge(data.fetch('meta', {}))
        @parser.parse(data, Resources::Profile, response: response)
      end
    end
  end
end
