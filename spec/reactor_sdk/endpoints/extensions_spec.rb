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
end
