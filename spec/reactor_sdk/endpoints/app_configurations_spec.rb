# frozen_string_literal: true

RSpec.describe ReactorSDK::Endpoints::AppConfigurations do
  subject(:client) { test_client }

  let(:attributes) do
    {
      'name' => 'Firebase Prod',
      'app_id' => 'com.acme.mobile',
      'platform' => 'mobile',
      'messaging_service' => 'fcm',
      'key_type' => 'p8'
    }
  end

  let(:single_response) do
    jsonapi_response(
      type: 'app_configurations',
      id: 'AC123',
      attributes: attributes
    ).to_json
  end

  let(:list_response) do
    jsonapi_list_response(
      type: 'app_configurations',
      items: [
        { id: 'AC123', attributes: attributes },
        { id: 'AC456', attributes: attributes.merge('name' => 'Firebase Stage') }
      ]
    ).to_json
  end

  describe '#list_for_company' do
    before do
      stub_request(:get, 'https://reactor.adobe.io/companies/CO123/app_configurations?page%5Bsize%5D=100')
        .to_return(status: 200, body: list_response, headers: { 'Content-Type' => 'application/json' })
    end

    it 'returns typed app configurations' do
      result = client.app_configurations.list_for_company('CO123')

      expect(result).to all(be_a(ReactorSDK::Resources::AppConfiguration))
      expect(result.map(&:id)).to eq(%w[AC123 AC456])
    end
  end

  describe '#find' do
    before do
      stub_request(:get, 'https://reactor.adobe.io/app_configurations/AC123')
        .to_return(status: 200, body: single_response, headers: { 'Content-Type' => 'application/json' })
    end

    it 'returns an app configuration' do
      result = client.app_configurations.find('AC123')

      expect(result).to be_a(ReactorSDK::Resources::AppConfiguration)
      expect(result.name).to eq('Firebase Prod')
    end
  end

  describe '#create' do
    before do
      stub_request(:post, 'https://reactor.adobe.io/companies/CO123/app_configurations')
        .to_return(status: 201, body: single_response, headers: { 'Content-Type' => 'application/json' })
    end

    it 'creates an app configuration from attributes' do
      result = client.app_configurations.create(company_id: 'CO123', attributes: attributes)

      expect(result).to be_a(ReactorSDK::Resources::AppConfiguration)
      expect(WebMock).to have_requested(:post, 'https://reactor.adobe.io/companies/CO123/app_configurations')
        .with(body: {
          data: {
            type: 'app_configurations',
            attributes: attributes
          }
        }.to_json)
    end
  end

  describe '#update' do
    before do
      stub_request(:patch, 'https://reactor.adobe.io/app_configurations/AC123')
        .to_return(status: 200, body: single_response, headers: { 'Content-Type' => 'application/json' })
    end

    it 'updates an app configuration' do
      result = client.app_configurations.update('AC123', name: 'Firebase Prod')

      expect(result).to be_a(ReactorSDK::Resources::AppConfiguration)
      expect(result.id).to eq('AC123')
    end
  end

  describe '#delete' do
    before do
      stub_request(:delete, 'https://reactor.adobe.io/app_configurations/AC123')
        .to_return(status: 204, body: '')
    end

    it 'returns nil on success' do
      expect(client.app_configurations.delete('AC123')).to be_nil
    end
  end

  describe '#company' do
    before do
      stub_request(:get, 'https://reactor.adobe.io/app_configurations/AC123/company')
        .to_return(
          status: 200,
          body: jsonapi_response(
            type: 'companies',
            id: 'CO123',
            attributes: { 'name' => 'Acme Org', 'org_id' => 'ORG123@AdobeOrg' }
          ).to_json,
          headers: { 'Content-Type' => 'application/json' }
        )
    end

    it 'returns the owning company' do
      result = client.app_configurations.company('AC123')

      expect(result).to be_a(ReactorSDK::Resources::Company)
      expect(result.id).to eq('CO123')
    end
  end
end
