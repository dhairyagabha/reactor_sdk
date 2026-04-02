# frozen_string_literal: true

RSpec.describe ReactorSDK::Endpoints::Search do
  subject(:client) { test_client }

  let(:response_body) do
    {
      'data' => [
        {
          'id' => 'PR123',
          'type' => 'properties',
          'attributes' => {
            'name' => 'Marketing Site',
            'platform' => 'web',
            'enabled' => true
          },
          'meta' => { 'match_score' => 3.2 }
        },
        {
          'id' => 'CB123',
          'type' => 'callbacks',
          'attributes' => {
            'url' => 'https://example.com/hooks/reactor',
            'subscriptions' => ['audit.event.created']
          }
        }
      ],
      'meta' => { 'total_hits' => 2 }
    }.to_json
  end

  describe '#perform' do
    before do
      stub_request(:post, 'https://reactor.adobe.io/search')
        .to_return(status: 200, body: response_body, headers: { 'Content-Type' => 'application/json' })
    end

    it 'returns typed heterogeneous search results and total hits' do
      result = client.search.perform(
        query: { 'attributes.name' => { value: 'Marketing' } },
        resource_types: %w[properties callbacks]
      )

      expect(result).to be_a(ReactorSDK::Resources::SearchResults)
      expect(result.total_hits).to eq(2)
      expect(result.results.first).to be_a(ReactorSDK::Resources::Property)
      expect(result.results.last).to be_a(ReactorSDK::Resources::Callback)
    end
  end
end
