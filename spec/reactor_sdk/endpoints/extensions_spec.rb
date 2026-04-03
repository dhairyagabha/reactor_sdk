# frozen_string_literal: true

##
# @file spec/reactor_sdk/endpoints/extensions_spec.rb
# @description Tests for ReactorSDK::Endpoints::Extensions.
#
#   Covers: list, find, revise, and error handling.
#

RSpec.describe ReactorSDK::Endpoints::Extensions do
  subject(:client) { test_client }

  let(:extension_attributes) do
    {
      'name' => 'Core',
      'delegate_descriptor_id' => 'core::extensionConfiguration::config',
      'settings' => { dataElementsEnabled: true }.to_json,
      'created_at' => '2024-01-01T00:00:00.000Z',
      'updated_at' => '2024-01-02T00:00:00.000Z'
    }
  end

  let(:single_response) do
    jsonapi_response(
      type: 'extensions',
      id: 'EX123',
      attributes: extension_attributes
    ).to_json
  end

  let(:list_response) do
    jsonapi_list_response(
      type: 'extensions',
      items: [
        { id: 'EX123', attributes: extension_attributes },
        { id: 'EX456', attributes: extension_attributes.merge('name' => 'Adobe Analytics') }
      ]
    ).to_json
  end

  describe '#list_for_property' do
    before do
      stub_request(:get, 'https://reactor.adobe.io/properties/PR123/extensions?page%5Bsize%5D=100')
        .to_return(status: 200, body: list_response, headers: { 'Content-Type' => 'application/json' })
    end

    it 'returns an array of Extension resources' do
      result = client.extensions.list_for_property('PR123')
      expect(result).to all(be_a(ReactorSDK::Resources::Extension))
    end

    it 'returns the correct number of extensions' do
      result = client.extensions.list_for_property('PR123')
      expect(result.length).to eq(2)
    end

    it 'maps attributes to Ruby methods' do
      result = client.extensions.list_for_property('PR123')
      expect(result.first.name).to eq('Core')
      expect(result.first.delegate_descriptor_id).to eq('core::extensionConfiguration::config')
    end
  end

  describe '#find' do
    before do
      stub_request(:get, 'https://reactor.adobe.io/extensions/EX123')
        .to_return(status: 200, body: single_response, headers: { 'Content-Type' => 'application/json' })
    end

    it 'returns an Extension resource' do
      result = client.extensions.find('EX123')
      expect(result).to be_a(ReactorSDK::Resources::Extension)
    end

    it 'maps the id correctly' do
      result = client.extensions.find('EX123')
      expect(result.id).to eq('EX123')
    end

    context 'when the extension does not exist' do
      before do
        stub_request(:get, 'https://reactor.adobe.io/extensions/EX_INVALID')
          .to_return(status: 404, body: { errors: [] }.to_json)
      end

      it 'raises ResourceNotFoundError' do
        expect do
          client.extensions.find('EX_INVALID')
        end.to raise_error(ReactorSDK::ResourceNotFoundError)
      end
    end
  end

  describe '#revise' do
    before do
      stub_request(:patch, 'https://reactor.adobe.io/extensions/EX123')
        .to_return(status: 200, body: single_response, headers: { 'Content-Type' => 'application/json' })
    end

    it 'returns a revised Extension resource' do
      result = client.extensions.revise('EX123')
      expect(result).to be_a(ReactorSDK::Resources::Extension)
    end

    it 'sends the revise action payload' do
      client.extensions.revise('EX123')

      expect(WebMock).to(
        have_requested(:patch, 'https://reactor.adobe.io/extensions/EX123')
          .with do |request|
            JSON.parse(request.body) == {
              'data' => {
                'type' => 'extensions',
                'attributes' => {},
                'id' => 'EX123',
                'meta' => { 'action' => 'revise' }
              }
            }
          end
      )
    end
  end

  describe 'additional operations' do
    it 'creates an extension with explicit relationships' do
      stub_request(:post, 'https://reactor.adobe.io/properties/PR123/extensions')
        .to_return(status: 201, body: single_response, headers: { 'Content-Type' => 'application/json' })

      result = client.extensions.create(
        property_id: 'PR123',
        attributes: { settings: '{}', delegate_descriptor_id: 'core::extensionConfiguration::config' },
        relationships: {
          extension_package: {
            data: { id: 'EP123', type: 'extension_packages' }
          }
        }
      )

      expect(result).to be_a(ReactorSDK::Resources::Extension)
    end

    it 'deletes an extension' do
      stub_request(:delete, 'https://reactor.adobe.io/extensions/EX123')
        .to_return(status: 204, body: '')

      expect(client.extensions.delete('EX123')).to be_nil
    end

    it 'fetches related resources and notes' do
      stub_request(:get, 'https://reactor.adobe.io/extensions/EX123/extension_package')
        .to_return(
          status: 200,
          body: jsonapi_response(
            type: 'extension_packages',
            id: 'EP123',
            attributes: { 'name' => 'core-package', 'version' => '1.0.0' }
          ).to_json,
          headers: { 'Content-Type' => 'application/json' }
        )
      stub_request(:get, 'https://reactor.adobe.io/extensions/EX123/libraries?page%5Bsize%5D=100')
        .to_return(
          status: 200,
          body: jsonapi_list_response(
            type: 'libraries',
            items: [{ id: 'LB123', attributes: { 'name' => 'Library', 'state' => 'development' } }]
          ).to_json,
          headers: { 'Content-Type' => 'application/json' }
        )
      stub_request(:get, 'https://reactor.adobe.io/extensions/EX123/property')
        .to_return(
          status: 200,
          body: jsonapi_response(
            type: 'properties',
            id: 'PR123',
            attributes: { 'name' => 'Property', 'platform' => 'web' }
          ).to_json,
          headers: { 'Content-Type' => 'application/json' }
        )
      stub_request(:get, 'https://reactor.adobe.io/extensions/EX123/origin')
        .to_return(status: 200, body: single_response, headers: { 'Content-Type' => 'application/json' })
      stub_request(:get, 'https://reactor.adobe.io/extensions/EX123/notes?page%5Bsize%5D=100')
        .to_return(
          status: 200,
          body: jsonapi_list_response(
            type: 'notes',
            items: [{ id: 'NT123', attributes: { 'text' => 'Extension note' } }]
          ).to_json,
          headers: { 'Content-Type' => 'application/json' }
        )
      stub_request(:post, 'https://reactor.adobe.io/extensions/EX123/notes')
        .to_return(
          status: 201,
          body: jsonapi_response(type: 'notes', id: 'NT123', attributes: { 'text' => 'Extension note' }).to_json,
          headers: { 'Content-Type' => 'application/json' }
        )

      expect(client.extensions.extension_package('EX123')).to be_a(ReactorSDK::Resources::ExtensionPackage)
      expect(client.extensions.libraries('EX123')).to all(be_a(ReactorSDK::Resources::Library))
      expect(client.extensions.property('EX123')).to be_a(ReactorSDK::Resources::Property)
      expect(client.extensions.origin('EX123')).to be_a(ReactorSDK::Resources::Extension)
      expect(client.extensions.list_notes('EX123').first).to be_a(ReactorSDK::Resources::Note)
      expect(client.extensions.create_note('EX123', 'Extension note')).to be_a(ReactorSDK::Resources::Note)
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
                'id' => 'EX123',
                'type' => 'extensions',
                'attributes' => { 'name' => 'Core', 'delegate_descriptor_id' => 'core::extensionConfiguration::config' },
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
                'id' => 'EX123',
                'type' => 'extensions',
                'attributes' => { 'name' => 'Core', 'delegate_descriptor_id' => 'core::extensionConfiguration::config' },
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
              'relationships' => { 'entity' => { 'data' => { 'id' => 'EX123', 'type' => 'extensions' } } }
            },
            'included' => [
              { 'id' => 'EX123', 'type' => 'extensions', 'attributes' => { 'name' => 'Core', 'delegate_descriptor_id' => 'core::extensionConfiguration::config' } }
            ]
          }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )
    end

    it 'returns an UpstreamChain for the extension' do
      result = client.extensions.upstream_chain('EX123', library_id: 'LB_DEV', property_id: 'PR123')

      expect(result).to be_a(ReactorSDK::Resources::UpstreamChain)
      expect(result.resource_type).to eq('extensions')
      expect(result.nearest_match.library.id).to eq('LB_STG')
    end
  end

  describe '#find_comprehensive' do
    let(:snapshot) { instance_double(ReactorSDK::Resources::LibrarySnapshot) }
    let(:libraries_endpoint) { instance_double(ReactorSDK::Endpoints::Libraries) }
    let(:comprehensive_extension) do
      ReactorSDK::Resources::ComprehensiveExtension.new(
        resource: ReactorSDK::Resources::Extension.new(
          id: 'EX123',
          type: 'extensions',
          attributes: { 'name' => 'Core', 'settings' => '{}' }
        ),
        data_elements: [],
        rule_components: [],
        rules: []
      )
    end

    before do
      allow(client.extensions).to receive(:libraries_endpoint).and_return(libraries_endpoint)
      allow(libraries_endpoint)
        .to receive(:find_snapshot)
        .with('LB_DEV', property_id: 'PR123')
        .and_return(snapshot)
    end

    it 'returns the comprehensive extension from the snapshot' do
      allow(snapshot).to receive(:comprehensive_resource)
        .with('EX123', resource_type: 'extensions')
        .and_return(comprehensive_extension)

      expect(client.extensions.find_comprehensive('EX123', library_id: 'LB_DEV', property_id: 'PR123')).to eq(comprehensive_extension)
    end

    it 'raises ResourceNotFoundError when the extension is missing from the snapshot' do
      allow(snapshot).to receive(:comprehensive_resource)
        .with('EX123', resource_type: 'extensions')
        .and_return(nil)

      expect do
        client.extensions.find_comprehensive('EX123', library_id: 'LB_DEV', property_id: 'PR123')
      end.to raise_error(ReactorSDK::ResourceNotFoundError)
    end
  end

  describe '#comprehensive_upstream_chain' do
    it 'delegates to the Libraries endpoint helper' do
      chain = instance_double(ReactorSDK::Resources::ComprehensiveUpstreamChain)
      libraries_endpoint = instance_double(ReactorSDK::Endpoints::Libraries)

      allow(client.extensions).to receive(:libraries_endpoint).and_return(libraries_endpoint)
      allow(libraries_endpoint)
        .to receive(:comprehensive_upstream_chain_for_resource)
        .with('EX123', library_id: 'LB_DEV', property_id: 'PR123', resource_type: 'extensions')
        .and_return(chain)

      expect(client.extensions.comprehensive_upstream_chain('EX123', library_id: 'LB_DEV', property_id: 'PR123')).to eq(chain)
    end
  end
end
