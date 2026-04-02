# frozen_string_literal: true

RSpec.describe ReactorSDK::Endpoints::Callbacks do
  subject(:client) { test_client }

  let(:attributes) do
    {
      'url' => 'https://example.com/hooks/reactor',
      'subscriptions' => ['audit.event.created']
    }
  end

  let(:single_response) do
    jsonapi_response(type: 'callbacks', id: 'CB123', attributes: attributes).to_json
  end

  let(:list_response) do
    jsonapi_list_response(
      type: 'callbacks',
      items: [
        { id: 'CB123', attributes: attributes },
        { id: 'CB456', attributes: attributes.merge('url' => 'https://example.com/hooks/reactor-2') }
      ]
    ).to_json
  end

  describe '#list_for_property' do
    before do
      stub_request(:get, 'https://reactor.adobe.io/properties/PR123/callbacks?page%5Bsize%5D=100')
        .to_return(status: 200, body: list_response, headers: { 'Content-Type' => 'application/json' })
    end

    it 'lists callbacks for a property' do
      result = client.callbacks.list_for_property('PR123')

      expect(result).to all(be_a(ReactorSDK::Resources::Callback))
      expect(result.first.url).to eq('https://example.com/hooks/reactor')
    end
  end

  describe '#find' do
    before do
      stub_request(:get, 'https://reactor.adobe.io/callbacks/CB123')
        .to_return(status: 200, body: single_response, headers: { 'Content-Type' => 'application/json' })
    end

    it 'returns a callback' do
      expect(client.callbacks.find('CB123')).to be_a(ReactorSDK::Resources::Callback)
    end
  end

  describe '#create' do
    before do
      stub_request(:post, 'https://reactor.adobe.io/properties/PR123/callbacks')
        .to_return(status: 201, body: single_response, headers: { 'Content-Type' => 'application/json' })
    end

    it 'creates a callback' do
      result = client.callbacks.create(property_id: 'PR123', attributes: attributes)

      expect(result).to be_a(ReactorSDK::Resources::Callback)
      expect(WebMock).to have_requested(:post, 'https://reactor.adobe.io/properties/PR123/callbacks')
        .with(body: {
          data: {
            type: 'callbacks',
            attributes: attributes
          }
        }.to_json)
    end
  end

  describe '#update' do
    before do
      stub_request(:patch, 'https://reactor.adobe.io/callbacks/CB123')
        .to_return(status: 200, body: single_response, headers: { 'Content-Type' => 'application/json' })
    end

    it 'updates a callback' do
      expect(client.callbacks.update('CB123', url: attributes['url'])).to be_a(ReactorSDK::Resources::Callback)
    end
  end

  describe '#delete' do
    before do
      stub_request(:delete, 'https://reactor.adobe.io/callbacks/CB123')
        .to_return(status: 204, body: '')
    end

    it 'returns nil on success' do
      expect(client.callbacks.delete('CB123')).to be_nil
    end
  end
end
