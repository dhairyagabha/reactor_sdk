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

      expect(WebMock).to have_requested(:patch, 'https://reactor.adobe.io/extensions/EX123')
        .with(body: {
          data: {
            id: 'EX123',
            type: 'extensions',
            meta: { action: 'revise' }
          }
        }.to_json)
    end
  end
end
