# frozen_string_literal: true

##
# @file spec/reactor_sdk/endpoints/companies_spec.rb
# @description Tests for ReactorSDK::Endpoints::Companies.
#
#   Covers: list, find, and error handling.
#

RSpec.describe ReactorSDK::Endpoints::Companies do
  subject(:client) { test_client }

  let(:company_attributes) do
    {
      'name' => 'Acme Org',
      'org_id' => 'ABC123@AdobeOrg',
      'created_at' => '2024-01-01T00:00:00.000Z',
      'updated_at' => '2024-01-02T00:00:00.000Z'
    }
  end

  let(:single_response) do
    jsonapi_response(
      type: 'companies',
      id: 'CO123',
      attributes: company_attributes
    ).to_json
  end

  let(:list_response) do
    jsonapi_list_response(
      type: 'companies',
      items: [
        { id: 'CO123', attributes: company_attributes },
        { id: 'CO456', attributes: company_attributes.merge('name' => 'Beta Org') }
      ]
    ).to_json
  end

  describe '#list' do
    before do
      stub_request(:get, 'https://reactor.adobe.io/companies?page%5Bsize%5D=100')
        .to_return(status: 200, body: list_response, headers: { 'Content-Type' => 'application/json' })
    end

    it 'returns an array of Company resources' do
      result = client.companies.list
      expect(result).to all(be_a(ReactorSDK::Resources::Company))
    end

    it 'returns the correct number of companies' do
      result = client.companies.list
      expect(result.length).to eq(2)
    end

    it 'maps attributes to Ruby methods' do
      result = client.companies.list
      expect(result.first.name).to eq('Acme Org')
      expect(result.first.org_id).to eq('ABC123@AdobeOrg')
    end
  end

  describe '#find' do
    before do
      stub_request(:get, 'https://reactor.adobe.io/companies/CO123')
        .to_return(status: 200, body: single_response, headers: { 'Content-Type' => 'application/json' })
    end

    it 'returns a Company resource' do
      result = client.companies.find('CO123')
      expect(result).to be_a(ReactorSDK::Resources::Company)
    end

    it 'maps the id correctly' do
      result = client.companies.find('CO123')
      expect(result.id).to eq('CO123')
    end

    it 'maps attributes to Ruby methods' do
      result = client.companies.find('CO123')
      expect(result.name).to eq('Acme Org')
      expect(result.org_id).to eq('ABC123@AdobeOrg')
    end

    context 'when the company does not exist' do
      before do
        stub_request(:get, 'https://reactor.adobe.io/companies/CO_INVALID')
          .to_return(status: 404, body: { errors: [] }.to_json)
      end

      it 'raises ResourceNotFoundError' do
        expect do
          client.companies.find('CO_INVALID')
        end.to raise_error(ReactorSDK::ResourceNotFoundError)
      end
    end
  end
end
