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

  describe '#upstream_chain' do
    before do
      stub_request(:get, 'https://reactor.adobe.io/libraries/LB_DEV')
        .to_return(status: 200, body: jsonapi_response(type: 'libraries', id: 'LB_DEV', attributes: { 'name' => 'Dev Library', 'state' => 'development' }).to_json)
      stub_request(:get, 'https://reactor.adobe.io/libraries/LB_STG')
        .to_return(status: 200, body: jsonapi_response(type: 'libraries', id: 'LB_STG', attributes: { 'name' => 'Staging Library', 'state' => 'development' }).to_json)
      stub_request(:get, 'https://reactor.adobe.io/properties/PR123/libraries?page%5Bsize%5D=100')
        .to_return(
          status: 200,
          body: {
            'data' => [
              { 'id' => 'LB_DEV', 'type' => 'libraries', 'attributes' => { 'name' => 'Dev Library', 'state' => 'development' } },
              { 'id' => 'LB_STG', 'type' => 'libraries', 'attributes' => { 'name' => 'Staging Library', 'state' => 'development' } }
            ],
            'links' => { 'next' => nil }
          }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )
      stub_request(:get, 'https://reactor.adobe.io/libraries/LB_DEV/relationships/environment')
        .to_return(status: 200, body: { 'data' => { 'id' => 'EN_DEV', 'type' => 'environments' } }.to_json)
      stub_request(:get, 'https://reactor.adobe.io/libraries/LB_STG/relationships/environment')
        .to_return(status: 200, body: { 'data' => { 'id' => 'EN_STG', 'type' => 'environments' } }.to_json)
      stub_request(:get, 'https://reactor.adobe.io/environments/EN_DEV')
        .to_return(status: 200, body: jsonapi_response(type: 'environments', id: 'EN_DEV', attributes: { 'stage' => 'development' }).to_json)
      stub_request(:get, 'https://reactor.adobe.io/environments/EN_STG')
        .to_return(status: 200, body: jsonapi_response(type: 'environments', id: 'EN_STG', attributes: { 'stage' => 'staging' }).to_json)
      stub_request(:get, 'https://reactor.adobe.io/libraries/LB_DEV?include=rules%2Cdata_elements%2Cextensions')
        .to_return(
          status: 200,
          body: {
            'data' => { 'id' => 'LB_DEV', 'type' => 'libraries', 'attributes' => { 'name' => 'Dev Library', 'state' => 'development' } },
            'included' => [
              {
                'id' => 'DE123',
                'type' => 'data_elements',
                'attributes' => { 'name' => 'Page Name' },
                'relationships' => { 'latest_revision' => { 'data' => { 'id' => 'RE_DEV', 'type' => 'revisions' } } }
              }
            ]
          }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )
      stub_request(:get, 'https://reactor.adobe.io/libraries/LB_STG?include=rules%2Cdata_elements%2Cextensions')
        .to_return(
          status: 200,
          body: {
            'data' => { 'id' => 'LB_STG', 'type' => 'libraries', 'attributes' => { 'name' => 'Staging Library', 'state' => 'development' } },
            'included' => [
              {
                'id' => 'DE123',
                'type' => 'data_elements',
                'attributes' => { 'name' => 'Page Name' },
                'relationships' => { 'latest_revision' => { 'data' => { 'id' => 'RE_STG', 'type' => 'revisions' } } }
              }
            ]
          }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )
      stub_request(:get, 'https://reactor.adobe.io/revisions/RE_STG')
        .to_return(
          status: 200,
          body: {
            'data' => {
              'id' => 'RE_STG',
              'type' => 'revisions',
              'attributes' => { 'activity_type' => 'updated' },
              'relationships' => { 'entity' => { 'data' => { 'id' => 'DE123', 'type' => 'data_elements' } } }
            },
            'included' => [
              { 'id' => 'DE123', 'type' => 'data_elements', 'attributes' => { 'name' => 'Page Name' } }
            ]
          }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )
    end

    it 'returns an UpstreamChain for the data element' do
      result = client.data_elements.upstream_chain('DE123', library_id: 'LB_DEV', property_id: 'PR123')

      expect(result).to be_a(ReactorSDK::Resources::UpstreamChain)
      expect(result.resource_type).to eq('data_elements')
      expect(result.nearest_match.library.id).to eq('LB_STG')
    end
  end

  describe '#find_comprehensive' do
    let(:snapshot) { instance_double(ReactorSDK::Resources::LibrarySnapshot) }
    let(:libraries_endpoint) { instance_double(ReactorSDK::Endpoints::Libraries) }
    let(:comprehensive_data_element) do
      ReactorSDK::Resources::ComprehensiveDataElement.new(
        resource: ReactorSDK::Resources::DataElement.new(
          id: 'DE123',
          type: 'data_elements',
          attributes: { 'name' => 'Page Name', 'settings' => '{}' }
        ),
        referenced_data_elements: [],
        impacted_rules: []
      )
    end

    before do
      allow(client.data_elements).to receive(:libraries_endpoint).and_return(libraries_endpoint)
      allow(libraries_endpoint)
        .to receive(:find_snapshot)
        .with('LB_DEV', property_id: 'PR123')
        .and_return(snapshot)
    end

    it 'returns the comprehensive data element from the snapshot' do
      allow(snapshot).to receive(:comprehensive_resource)
        .with('DE123', resource_type: 'data_elements')
        .and_return(comprehensive_data_element)

      expect(
        client.data_elements.find_comprehensive('DE123', library_id: 'LB_DEV', property_id: 'PR123')
      ).to eq(comprehensive_data_element)
    end

    it 'raises ResourceNotFoundError when the data element is missing from the snapshot' do
      allow(snapshot).to receive(:comprehensive_resource)
        .with('DE123', resource_type: 'data_elements')
        .and_return(nil)

      expect do
        client.data_elements.find_comprehensive('DE123', library_id: 'LB_DEV', property_id: 'PR123')
      end.to raise_error(ReactorSDK::ResourceNotFoundError)
    end
  end

  describe '#comprehensive_upstream_chain' do
    it 'delegates to the Libraries endpoint helper' do
      chain = instance_double(ReactorSDK::Resources::ComprehensiveUpstreamChain)
      libraries_endpoint = instance_double(ReactorSDK::Endpoints::Libraries)

      allow(client.data_elements).to receive(:libraries_endpoint).and_return(libraries_endpoint)
      allow(libraries_endpoint)
        .to receive(:comprehensive_upstream_chain_for_resource)
        .with('DE123', library_id: 'LB_DEV', property_id: 'PR123', resource_type: 'data_elements')
        .and_return(chain)

      expect(client.data_elements.comprehensive_upstream_chain('DE123', library_id: 'LB_DEV', property_id: 'PR123')).to eq(chain)
    end
  end
end
