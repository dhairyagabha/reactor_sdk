# frozen_string_literal: true

##
# @file spec/reactor_sdk/endpoints/properties_spec.rb
# @description Tests for ReactorSDK::Endpoints::Properties.
#
#   Uses WebMock to stub HTTP calls — no real API calls are made.
#   Tests cover: list pagination, find, create, update, delete,
#   and error handling for not-found and validation failures.
#

RSpec.describe ReactorSDK::Endpoints::Properties do
  subject(:client) { test_client }

  let(:property_attributes) do
    {
      'name' => 'My Test Property',
      'platform' => 'web',
      'enabled' => true,
      'domains' => ['example.com'],
      'created_at' => '2024-01-01T00:00:00.000Z',
      'updated_at' => '2024-01-01T00:00:00.000Z'
    }
  end

  let(:single_response) do
    jsonapi_response(
      type: 'properties',
      id: 'PR123',
      attributes: property_attributes
    ).to_json
  end

  let(:list_response) do
    jsonapi_list_response(
      type: 'properties',
      items: [
        { id: 'PR123', attributes: property_attributes },
        { id: 'PR456', attributes: property_attributes.merge('name' => 'Second Property') }
      ]
    ).to_json
  end

  describe '#list_for_company' do
    before do
      stub_request(:get, 'https://reactor.adobe.io/companies/CO123/properties?page%5Bsize%5D=100')
        .to_return(status: 200, body: list_response, headers: { 'Content-Type' => 'application/json' })
    end

    it 'returns an array of Property resources' do
      result = client.properties.list_for_company('CO123')
      expect(result).to all(be_a(ReactorSDK::Resources::Property))
    end

    it 'returns the correct number of properties' do
      result = client.properties.list_for_company('CO123')
      expect(result.length).to eq(2)
    end

    it 'maps attributes to Ruby methods' do
      result = client.properties.list_for_company('CO123')
      expect(result.first.name).to eq('My Test Property')
      expect(result.first.platform).to eq('web')
      expect(result.first.enabled?).to be(true)
      expect(result.first.domains).to eq(['example.com'])
    end

    it 'returns the correct ids' do
      result = client.properties.list_for_company('CO123')
      expect(result.map(&:id)).to eq(%w[PR123 PR456])
    end
  end

  describe '#find' do
    before do
      stub_request(:get, 'https://reactor.adobe.io/properties/PR123')
        .to_return(status: 200, body: single_response, headers: { 'Content-Type' => 'application/json' })
    end

    it 'returns a Property resource' do
      result = client.properties.find('PR123')
      expect(result).to be_a(ReactorSDK::Resources::Property)
    end

    it 'maps the id correctly' do
      result = client.properties.find('PR123')
      expect(result.id).to eq('PR123')
    end

    it 'maps attributes to Ruby methods' do
      result = client.properties.find('PR123')
      expect(result.name).to eq('My Test Property')
      expect(result.platform).to eq('web')
    end

    context 'when the property does not exist' do
      before do
        stub_request(:get, 'https://reactor.adobe.io/properties/PR_INVALID')
          .to_return(status: 404, body: { errors: [] }.to_json)
      end

      it 'raises ResourceNotFoundError' do
        expect do
          client.properties.find('PR_INVALID')
        end.to raise_error(ReactorSDK::ResourceNotFoundError)
      end
    end
  end

  describe '#create' do
    before do
      stub_request(:post, 'https://reactor.adobe.io/companies/CO123/properties')
        .to_return(status: 201, body: single_response, headers: { 'Content-Type' => 'application/json' })
    end

    it 'returns a Property resource' do
      result = client.properties.create(
        company_id: 'CO123',
        name: 'My Test Property',
        platform: 'web',
        domains: ['example.com']
      )
      expect(result).to be_a(ReactorSDK::Resources::Property)
    end

    it 'maps attributes on the returned resource' do
      result = client.properties.create(
        company_id: 'CO123',
        name: 'My Test Property',
        platform: 'web'
      )
      expect(result.name).to eq('My Test Property')
    end

    context 'when attributes are invalid' do
      before do
        stub_request(:post, 'https://reactor.adobe.io/companies/CO123/properties')
          .to_return(
            status: 422,
            body: { errors: [{ detail: "Name can't be blank" }] }.to_json
          )
      end

      it 'raises UnprocessableEntityError' do
        expect do
          client.properties.create(company_id: 'CO123', name: '', platform: 'web')
        end.to raise_error(ReactorSDK::UnprocessableEntityError)
      end
    end
  end

  describe '#delete' do
    before do
      stub_request(:delete, 'https://reactor.adobe.io/properties/PR123')
        .to_return(status: 204, body: '')
    end

    it 'returns nil on success' do
      result = client.properties.delete('PR123')
      expect(result).to be_nil
    end
  end

  describe '#list_notes' do
    before do
      stub_request(:get, 'https://reactor.adobe.io/properties/PR123/notes?page%5Bsize%5D=100')
        .to_return(
          status: 200,
          body: jsonapi_list_response(
            type: 'notes',
            items: [{ id: 'NT123', attributes: { 'text' => 'Property note' } }]
          ).to_json,
          headers: { 'Content-Type' => 'application/json' }
        )
    end

    it 'returns notes for a property' do
      result = client.properties.list_notes('PR123')

      expect(result).to all(be_a(ReactorSDK::Resources::Note))
      expect(result.first.text).to eq('Property note')
    end
  end
end
