# frozen_string_literal: true

##
# @file spec/reactor_sdk/endpoints/data_elements_spec.rb
# @description Tests for ReactorSDK::Endpoints::DataElements.
#
#   Covers: list, find, create, update, revise, delete,
#   and error handling.
#

RSpec.describe ReactorSDK::Endpoints::DataElements do
  subject(:client) { test_client }

  let(:data_element_attributes) do
    {
      'name' => 'Page Name',
      'enabled' => true,
      'delegate_descriptor_id' => 'core::dataElements::custom-code',
      'settings' => { source: 'return document.title;' }.to_json,
      'storage_duration' => 'pageview',
      'created_at' => '2024-01-01T00:00:00.000Z',
      'updated_at' => '2024-01-02T00:00:00.000Z'
    }
  end

  let(:single_response) do
    jsonapi_response(
      type: 'data_elements',
      id: 'DE123',
      attributes: data_element_attributes
    ).to_json
  end

  let(:list_response) do
    jsonapi_list_response(
      type: 'data_elements',
      items: [
        { id: 'DE123', attributes: data_element_attributes },
        { id: 'DE456', attributes: data_element_attributes.merge('name' => 'Page URL') }
      ]
    ).to_json
  end

  describe '#list_for_property' do
    before do
      stub_request(:get, 'https://reactor.adobe.io/properties/PR123/data_elements?page%5Bsize%5D=100')
        .to_return(status: 200, body: list_response, headers: { 'Content-Type' => 'application/json' })
    end

    it 'returns an array of DataElement resources' do
      result = client.data_elements.list_for_property('PR123')
      expect(result).to all(be_a(ReactorSDK::Resources::DataElement))
    end

    it 'returns the correct number of data elements' do
      result = client.data_elements.list_for_property('PR123')
      expect(result.length).to eq(2)
    end

    it 'maps attributes to Ruby methods' do
      result = client.data_elements.list_for_property('PR123')
      expect(result.first.name).to eq('Page Name')
      expect(result.first.delegate_descriptor_id).to eq('core::dataElements::custom-code')
      expect(result.first.enabled?).to be(true)
    end
  end

  describe '#find' do
    before do
      stub_request(:get, 'https://reactor.adobe.io/data_elements/DE123')
        .to_return(status: 200, body: single_response, headers: { 'Content-Type' => 'application/json' })
    end

    it 'returns a DataElement resource' do
      result = client.data_elements.find('DE123')
      expect(result).to be_a(ReactorSDK::Resources::DataElement)
    end

    it 'maps the id correctly' do
      result = client.data_elements.find('DE123')
      expect(result.id).to eq('DE123')
    end

    context 'when the data element does not exist' do
      before do
        stub_request(:get, 'https://reactor.adobe.io/data_elements/DE_INVALID')
          .to_return(status: 404, body: { errors: [] }.to_json)
      end

      it 'raises ResourceNotFoundError' do
        expect do
          client.data_elements.find('DE_INVALID')
        end.to raise_error(ReactorSDK::ResourceNotFoundError)
      end
    end
  end

  describe '#create' do
    before do
      stub_request(:post, 'https://reactor.adobe.io/properties/PR123/data_elements')
        .to_return(status: 201, body: single_response, headers: { 'Content-Type' => 'application/json' })
    end

    it 'returns a DataElement resource' do
      result = client.data_elements.create(
        property_id: 'PR123',
        name: 'Page Name',
        delegate_descriptor_id: 'core::dataElements::custom-code',
        settings: { source: 'return document.title;' }.to_json,
        extension_id: 'EX123'
      )
      expect(result).to be_a(ReactorSDK::Resources::DataElement)
    end

    it 'sends the correct payload including the extension relationship' do
      client.data_elements.create(
        property_id: 'PR123',
        name: 'Page Name',
        delegate_descriptor_id: 'core::dataElements::custom-code',
        settings: { source: 'return document.title;' }.to_json,
        extension_id: 'EX123'
      )

      expect(WebMock).to have_requested(:post, 'https://reactor.adobe.io/properties/PR123/data_elements')
        .with(body: {
          data: {
            type: 'data_elements',
            attributes: {
              name: 'Page Name',
              delegate_descriptor_id: 'core::dataElements::custom-code',
              settings: { source: 'return document.title;' }.to_json,
              enabled: true
            },
            relationships: {
              extension: {
                data: { id: 'EX123', type: 'extensions' }
              }
            }
          }
        }.to_json)
    end
  end

  describe '#update' do
    before do
      stub_request(:patch, 'https://reactor.adobe.io/data_elements/DE123')
        .to_return(
          status: 200,
          body: jsonapi_response(
            type: 'data_elements',
            id: 'DE123',
            attributes: data_element_attributes.merge('name' => 'Updated Page Name')
          ).to_json,
          headers: { 'Content-Type' => 'application/json' }
        )
    end

    it 'returns the updated DataElement resource' do
      result = client.data_elements.update('DE123', { name: 'Updated Page Name' })
      expect(result).to be_a(ReactorSDK::Resources::DataElement)
    end

    it 'reflects the updated attributes' do
      result = client.data_elements.update('DE123', { name: 'Updated Page Name' })
      expect(result.name).to eq('Updated Page Name')
    end
  end

  describe '#revise' do
    before do
      stub_request(:patch, 'https://reactor.adobe.io/data_elements/DE123')
        .to_return(status: 200, body: single_response, headers: { 'Content-Type' => 'application/json' })
    end

    it 'returns a revised DataElement resource' do
      result = client.data_elements.revise('DE123')
      expect(result).to be_a(ReactorSDK::Resources::DataElement)
    end

    it 'sends the revise action payload' do
      client.data_elements.revise('DE123')

      expect(WebMock).to have_requested(:patch, 'https://reactor.adobe.io/data_elements/DE123')
        .with(body: {
          data: {
            id: 'DE123',
            type: 'data_elements',
            meta: { action: 'revise' }
          }
        }.to_json)
    end
  end

  describe '#delete' do
    before do
      stub_request(:delete, 'https://reactor.adobe.io/data_elements/DE123')
        .to_return(status: 204, body: '')
    end

    it 'returns nil on success' do
      result = client.data_elements.delete('DE123')
      expect(result).to be_nil
    end
  end

  describe 'notes support' do
    before do
      stub_request(:get, 'https://reactor.adobe.io/data_elements/DE123/notes?page%5Bsize%5D=100')
        .to_return(
          status: 200,
          body: jsonapi_list_response(
            type: 'notes',
            items: [{ id: 'NT123', attributes: { 'text' => 'DE note' } }]
          ).to_json,
          headers: { 'Content-Type' => 'application/json' }
        )
      stub_request(:post, 'https://reactor.adobe.io/data_elements/DE123/notes')
        .to_return(
          status: 201,
          body: jsonapi_response(type: 'notes', id: 'NT123', attributes: { 'text' => 'DE note' }).to_json,
          headers: { 'Content-Type' => 'application/json' }
        )
    end

    it 'lists notes for a data element' do
      expect(client.data_elements.list_notes('DE123').first).to be_a(ReactorSDK::Resources::Note)
    end

    it 'creates a note for a data element' do
      expect(client.data_elements.create_note('DE123', 'DE note')).to be_a(ReactorSDK::Resources::Note)
    end
  end
end
