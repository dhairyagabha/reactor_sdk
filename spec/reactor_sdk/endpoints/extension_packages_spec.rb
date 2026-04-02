# frozen_string_literal: true

require 'tempfile'

RSpec.describe ReactorSDK::Endpoints::ExtensionPackages do
  subject(:client) { test_client }

  let(:attributes) do
    {
      'name' => 'acme-extension',
      'display_name' => 'Acme Extension',
      'platform' => 'web',
      'availability' => 'private',
      'version' => '1.0.0'
    }
  end

  let(:single_response) do
    jsonapi_response(type: 'extension_packages', id: 'EP123', attributes: attributes).to_json
  end

  let(:list_response) do
    jsonapi_list_response(
      type: 'extension_packages',
      items: [
        { id: 'EP123', attributes: attributes },
        { id: 'EP456', attributes: attributes.merge('version' => '1.1.0') }
      ]
    ).to_json
  end

  let(:authz_list_response) do
    jsonapi_list_response(
      type: 'extension_package_usage_authorizations',
      items: [
        {
          id: 'EA123',
          attributes: {
            'authorized_org_id' => 'ORG123@AdobeOrg',
            'state' => 'pending_approval'
          }
        }
      ]
    ).to_json
  end

  let!(:package_file) do
    Tempfile.new(['extension-package', '.zip']).tap do |file|
      file.write('zip-bytes')
      file.rewind
    end
  end

  after do
    package_file.close!
  end

  describe '#list' do
    before do
      stub_request(:get, 'https://reactor.adobe.io/extension_packages?page%5Bsize%5D=100')
        .to_return(status: 200, body: list_response, headers: { 'Content-Type' => 'application/json' })
    end

    it 'returns extension packages' do
      result = client.extension_packages.list

      expect(result).to all(be_a(ReactorSDK::Resources::ExtensionPackage))
      expect(result.first.version).to eq('1.0.0')
    end
  end

  describe '#find' do
    before do
      stub_request(:get, 'https://reactor.adobe.io/extension_packages/EP123')
        .to_return(status: 200, body: single_response, headers: { 'Content-Type' => 'application/json' })
    end

    it 'returns an extension package' do
      expect(client.extension_packages.find('EP123')).to be_a(ReactorSDK::Resources::ExtensionPackage)
    end
  end

  describe '#create and #update' do
    before do
      stub_request(:post, 'https://reactor.adobe.io/extension_packages')
        .to_return(status: 202, body: single_response, headers: { 'Content-Type' => 'application/json' })
      stub_request(:post, 'https://reactor.adobe.io/extension_packages/EP123')
        .to_return(status: 200, body: single_response, headers: { 'Content-Type' => 'application/json' })
    end

    it 'uploads an extension package archive to create a package' do
      result = client.extension_packages.create(package_path: package_file.path)

      expect(result).to be_a(ReactorSDK::Resources::ExtensionPackage)
      expect(WebMock).to(
        have_requested(:post, 'https://reactor.adobe.io/extension_packages')
          .with { |request| request.headers['Content-Type'].include?('multipart/form-data') }
      )
    end

    it 'uploads an archive to update a development package' do
      result = client.extension_packages.update('EP123', package_path: package_file.path)

      expect(result).to be_a(ReactorSDK::Resources::ExtensionPackage)
      expect(WebMock).to(
        have_requested(:post, 'https://reactor.adobe.io/extension_packages/EP123')
          .with { |request| request.headers['Content-Type'].include?('multipart/form-data') }
      )
    end
  end

  describe '#private_release and #discontinue' do
    before do
      stub_request(:patch, 'https://reactor.adobe.io/extension_packages/EP123')
        .to_return(status: 200, body: single_response, headers: { 'Content-Type' => 'application/json' })
    end

    it 'sends the release_private action' do
      client.extension_packages.private_release('EP123')

      expect(WebMock).to(
        have_requested(:patch, 'https://reactor.adobe.io/extension_packages/EP123')
          .with do |request|
            JSON.parse(request.body) == {
              'data' => {
                'type' => 'extension_packages',
                'attributes' => {},
                'id' => 'EP123',
                'meta' => { 'action' => 'release_private' }
              }
            }
          end
      )
    end

    it 'sends the discontinue action' do
      client.extension_packages.discontinue('EP123')

      expect(WebMock).to(
        have_requested(:patch, 'https://reactor.adobe.io/extension_packages/EP123')
          .with do |request|
            JSON.parse(request.body) == {
              'data' => {
                'type' => 'extension_packages',
                'attributes' => {},
                'id' => 'EP123',
                'meta' => { 'action' => 'discontinue' }
              }
            }
          end
      )
    end
  end

  describe '#versions and #usage_authorizations' do
    before do
      stub_request(:get, 'https://reactor.adobe.io/extension_packages/EP123/versions?page%5Bsize%5D=100')
        .to_return(status: 200, body: list_response, headers: { 'Content-Type' => 'application/json' })
      stub_request(:get,
                   'https://reactor.adobe.io/extension_packages/EP123/extension_package_usage_authorizations?page%5Bsize%5D=100')
        .to_return(status: 200, body: authz_list_response, headers: { 'Content-Type' => 'application/json' })
    end

    it 'lists package versions' do
      expect(client.extension_packages.versions('EP123')).to all(be_a(ReactorSDK::Resources::ExtensionPackage))
    end

    it 'lists package usage authorizations' do
      expect(client.extension_packages.usage_authorizations('EP123'))
        .to all(be_a(ReactorSDK::Resources::ExtensionPackageUsageAuthorization))
    end
  end
end
