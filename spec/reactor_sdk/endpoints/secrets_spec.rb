# frozen_string_literal: true

RSpec.describe ReactorSDK::Endpoints::Secrets do
  subject(:client) { test_client }

  let(:attributes) do
    {
      'name' => 'OAuth Secret',
      'type_of' => 'oauth2',
      'credentials' => { 'client_id' => 'abc123' }
    }
  end

  let(:single_response) do
    jsonapi_response(type: 'secrets', id: 'SE123', attributes: attributes).to_json
  end

  let(:list_response) do
    jsonapi_list_response(
      type: 'secrets',
      items: [
        { id: 'SE123', attributes: attributes },
        { id: 'SE456', attributes: attributes.merge('name' => 'Retry Secret') }
      ]
    ).to_json
  end

  describe '#list_for_property' do
    before do
      stub_request(:get, 'https://reactor.adobe.io/properties/PR123/secrets?page%5Bsize%5D=100')
        .to_return(status: 200, body: list_response, headers: { 'Content-Type' => 'application/json' })
    end

    it 'lists secrets for a property' do
      result = client.secrets.list_for_property('PR123')

      expect(result).to all(be_a(ReactorSDK::Resources::Secret))
      expect(result.first.type_of).to eq('oauth2')
    end
  end

  describe '#list_for_environment' do
    before do
      stub_request(:get, 'https://reactor.adobe.io/environments/EN123/secrets?page%5Bsize%5D=100')
        .to_return(status: 200, body: list_response, headers: { 'Content-Type' => 'application/json' })
    end

    it 'lists secrets for an environment' do
      expect(client.secrets.list_for_environment('EN123').length).to eq(2)
    end
  end

  describe '#create' do
    before do
      stub_request(:post, 'https://reactor.adobe.io/properties/PR123/secrets')
        .to_return(status: 201, body: single_response, headers: { 'Content-Type' => 'application/json' })
    end

    it 'creates a secret with an environment relationship' do
      result = client.secrets.create(
        property_id: 'PR123',
        environment_id: 'EN123',
        attributes: attributes
      )

      expect(result).to be_a(ReactorSDK::Resources::Secret)
      expect(WebMock).to have_requested(:post, 'https://reactor.adobe.io/properties/PR123/secrets')
        .with(body: {
          data: {
            type: 'secrets',
            attributes: attributes,
            relationships: {
              environment: {
                data: { id: 'EN123', type: 'environments' }
              }
            }
          }
        }.to_json)
    end
  end

  describe '#test_or_retry' do
    before do
      stub_request(:patch, 'https://reactor.adobe.io/secrets/SE123')
        .to_return(status: 200, body: single_response, headers: { 'Content-Type' => 'application/json' })
    end

    it 'sends the requested secret action' do
      result = client.secrets.test_or_retry('SE123', type_of: 'oauth2', action: 'test')

      expect(result).to be_a(ReactorSDK::Resources::Secret)
      expect(WebMock).to(
        have_requested(:patch, 'https://reactor.adobe.io/secrets/SE123')
          .with do |request|
            JSON.parse(request.body) == {
              'data' => {
                'type' => 'secrets',
                'attributes' => { 'type_of' => 'oauth2' },
                'id' => 'SE123',
                'meta' => { 'action' => 'test' }
              }
            }
          end
      )
    end
  end

  describe '#data_elements' do
    before do
      stub_request(:get, 'https://reactor.adobe.io/secrets/SE123/data_elements?page%5Bsize%5D=100')
        .to_return(
          status: 200,
          body: jsonapi_list_response(
            type: 'data_elements',
            items: [{ id: 'DE123', attributes: { 'name' => 'Secret Backed DE' } }]
          ).to_json,
          headers: { 'Content-Type' => 'application/json' }
        )
    end

    it 'returns related data elements' do
      result = client.secrets.data_elements('SE123')

      expect(result).to all(be_a(ReactorSDK::Resources::DataElement))
    end
  end

  describe '#environment and #property' do
    it 'returns the related environment' do
      stub_request(:get, 'https://reactor.adobe.io/secrets/SE123/environment')
        .to_return(
          status: 200,
          body: jsonapi_response(
            type: 'environments',
            id: 'EN123',
            attributes: { 'name' => 'Dev', 'stage' => 'development' }
          ).to_json,
          headers: { 'Content-Type' => 'application/json' }
        )

      expect(client.secrets.environment('SE123')).to be_a(ReactorSDK::Resources::Environment)
    end

    it 'returns the related property' do
      stub_request(:get, 'https://reactor.adobe.io/secrets/SE123/property')
        .to_return(
          status: 200,
          body: jsonapi_response(
            type: 'properties',
            id: 'PR123',
            attributes: { 'name' => 'Edge Property', 'platform' => 'edge' }
          ).to_json,
          headers: { 'Content-Type' => 'application/json' }
        )

      expect(client.secrets.property('SE123')).to be_a(ReactorSDK::Resources::Property)
    end
  end

  describe 'notes support' do
    let(:note_response) do
      jsonapi_list_response(
        type: 'notes',
        items: [{ id: 'NT123', attributes: { 'text' => 'Secret note' } }]
      ).to_json
    end

    before do
      stub_request(:get, 'https://reactor.adobe.io/secrets/SE123/notes?page%5Bsize%5D=100')
        .to_return(status: 200, body: note_response, headers: { 'Content-Type' => 'application/json' })
      stub_request(:post, 'https://reactor.adobe.io/secrets/SE123/notes')
        .to_return(
          status: 201,
          body: jsonapi_response(type: 'notes', id: 'NT123', attributes: { 'text' => 'Secret note' }).to_json,
          headers: { 'Content-Type' => 'application/json' }
        )
    end

    it 'lists notes' do
      expect(client.secrets.list_notes('SE123').first).to be_a(ReactorSDK::Resources::Note)
    end

    it 'creates notes' do
      expect(client.secrets.create_note('SE123', 'Secret note')).to be_a(ReactorSDK::Resources::Note)
    end
  end
end
