# frozen_string_literal: true

RSpec.describe ReactorSDK::Endpoints::ExtensionPackageUsageAuthorizations do
  subject(:client) { test_client }

  let(:attributes) do
    {
      'authorized_org_id' => 'ORG123@AdobeOrg',
      'authorized_org_name' => 'Partner Org',
      'state' => 'pending_approval'
    }
  end

  let(:list_response) do
    jsonapi_list_response(
      type: 'extension_package_usage_authorizations',
      items: [{ id: 'EA123', attributes: attributes }]
    ).to_json
  end

  let(:single_response) do
    jsonapi_response(
      type: 'extension_package_usage_authorizations',
      id: 'EA123',
      attributes: attributes
    ).to_json
  end

  describe '#list and #list_for_package' do
    before do
      stub_request(:get, 'https://reactor.adobe.io/extension_package_usage_authorizations?page%5Bsize%5D=100')
        .to_return(status: 200, body: list_response, headers: { 'Content-Type' => 'application/json' })
      stub_request(:get,
                   'https://reactor.adobe.io/extension_packages/EP123/extension_package_usage_authorizations?page%5Bsize%5D=100')
        .to_return(status: 200, body: list_response, headers: { 'Content-Type' => 'application/json' })
    end

    it 'lists all usage authorizations' do
      expect(client.extension_package_usage_authorizations.list.first)
        .to be_a(ReactorSDK::Resources::ExtensionPackageUsageAuthorization)
    end

    it 'lists usage authorizations for a package' do
      expect(client.extension_package_usage_authorizations.list_for_package('EP123').length).to eq(1)
    end
  end

  describe '#create' do
    before do
      stub_request(:post, 'https://reactor.adobe.io/extension_packages/EP123/extension_package_usage_authorizations')
        .to_return(status: 201, body: single_response, headers: { 'Content-Type' => 'application/json' })
    end

    it 'creates a usage authorization for a package' do
      result = client.extension_package_usage_authorizations.create(
        extension_package_id: 'EP123',
        authorized_org_id: 'ORG123@AdobeOrg'
      )

      expect(result).to be_a(ReactorSDK::Resources::ExtensionPackageUsageAuthorization)
    end
  end

  describe '#update and #delete' do
    before do
      stub_request(:patch, 'https://reactor.adobe.io/extension_package_usage_authorizations/EA123')
        .to_return(status: 200, body: single_response, headers: { 'Content-Type' => 'application/json' })
      stub_request(:delete, 'https://reactor.adobe.io/extension_package_usage_authorizations/EA123')
        .to_return(status: 204, body: '')
    end

    it 'updates the authorization state' do
      result = client.extension_package_usage_authorizations.update('EA123', state: 'approved')

      expect(result).to be_a(ReactorSDK::Resources::ExtensionPackageUsageAuthorization)
    end

    it 'deletes an authorization' do
      expect(client.extension_package_usage_authorizations.delete('EA123')).to be_nil
    end
  end

  describe '#extension_package' do
    before do
      stub_request(:get, 'https://reactor.adobe.io/extension_package_usage_authorizations/EA123/extension_package')
        .to_return(
          status: 200,
          body: jsonapi_response(
            type: 'extension_packages',
            id: 'EP123',
            attributes: { 'name' => 'acme-extension', 'version' => '1.0.0' }
          ).to_json,
          headers: { 'Content-Type' => 'application/json' }
        )
    end

    it 'returns the related extension package' do
      expect(client.extension_package_usage_authorizations.extension_package('EA123'))
        .to be_a(ReactorSDK::Resources::ExtensionPackage)
    end
  end
end
