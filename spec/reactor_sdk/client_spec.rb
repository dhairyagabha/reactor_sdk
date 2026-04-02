# frozen_string_literal: true

##
# @file spec/reactor_sdk/client_spec.rb
# @description Tests for ReactorSDK::Client.
#
#   Covers: initialization, credential validation, all endpoint
#   group availability, and config exposure.
#

RSpec.describe ReactorSDK::Client do
  let(:valid_params) do
    {
      client_id: 'test_client_id',
      client_secret: 'test_client_secret',
      org_id: 'test_org_id',
      ims_token_url: 'http://localhost:9292/token'
    }
  end

  before do
    stub_request(:post, 'http://localhost:9292/token')
      .to_return(
        status: 200,
        body: { access_token: 'test_token', expires_in: 86_400 }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
  end

  describe '#initialize' do
    subject(:client) { described_class.new(**valid_params) }

    it 'creates a client successfully' do
      expect(client).to be_a(described_class)
    end

    it 'exposes the configuration' do
      expect(client.config).to be_a(ReactorSDK::Configuration)
    end

    it 'stores the org_id on the config' do
      expect(client.config.org_id).to eq('test_org_id')
    end

    it 'raises ConfigurationError when client_id is blank' do
      expect do
        described_class.new(**valid_params, client_id: '')
      end.to raise_error(ReactorSDK::ConfigurationError)
    end
  end

  describe 'endpoint groups' do
    subject(:client) { described_class.new(**valid_params) }

    it 'exposes companies endpoint' do
      expect(client.companies).to be_a(ReactorSDK::Endpoints::Companies)
    end

    it 'exposes properties endpoint' do
      expect(client.properties).to be_a(ReactorSDK::Endpoints::Properties)
    end

    it 'exposes app_configurations endpoint' do
      expect(client.app_configurations).to be_a(ReactorSDK::Endpoints::AppConfigurations)
    end

    it 'exposes callbacks endpoint' do
      expect(client.callbacks).to be_a(ReactorSDK::Endpoints::Callbacks)
    end

    it 'exposes secrets endpoint' do
      expect(client.secrets).to be_a(ReactorSDK::Endpoints::Secrets)
    end

    it 'exposes environments endpoint' do
      expect(client.environments).to be_a(ReactorSDK::Endpoints::Environments)
    end

    it 'exposes hosts endpoint' do
      expect(client.hosts).to be_a(ReactorSDK::Endpoints::Hosts)
    end

    it 'exposes rules endpoint' do
      expect(client.rules).to be_a(ReactorSDK::Endpoints::Rules)
    end

    it 'exposes rule_components endpoint' do
      expect(client.rule_components).to be_a(ReactorSDK::Endpoints::RuleComponents)
    end

    it 'exposes data_elements endpoint' do
      expect(client.data_elements).to be_a(ReactorSDK::Endpoints::DataElements)
    end

    it 'exposes extensions endpoint' do
      expect(client.extensions).to be_a(ReactorSDK::Endpoints::Extensions)
    end

    it 'exposes extension_packages endpoint' do
      expect(client.extension_packages).to be_a(ReactorSDK::Endpoints::ExtensionPackages)
    end

    it 'exposes extension_package_usage_authorizations endpoint' do
      expect(client.extension_package_usage_authorizations)
        .to be_a(ReactorSDK::Endpoints::ExtensionPackageUsageAuthorizations)
    end

    it 'exposes libraries endpoint' do
      expect(client.libraries).to be_a(ReactorSDK::Endpoints::Libraries)
    end

    it 'exposes builds endpoint' do
      expect(client.builds).to be_a(ReactorSDK::Endpoints::Builds)
    end

    it 'exposes audit_events endpoint' do
      expect(client.audit_events).to be_a(ReactorSDK::Endpoints::AuditEvents)
    end

    it 'exposes revisions endpoint' do
      expect(client.revisions).to be_a(ReactorSDK::Endpoints::Revisions)
    end

    it 'exposes profiles endpoint' do
      expect(client.profiles).to be_a(ReactorSDK::Endpoints::Profiles)
    end

    it 'exposes search endpoint' do
      expect(client.search).to be_a(ReactorSDK::Endpoints::Search)
    end

    it 'exposes notes endpoint' do
      expect(client.notes).to be_a(ReactorSDK::Endpoints::Notes)
    end
  end

  describe 'multiple client instances' do
    let(:client_a_params) do
      {
        client_id: 'client_a',
        client_secret: 'secret_a',
        org_id: 'org_a@AdobeOrg',
        ims_token_url: 'http://localhost:9292/token_a'
      }
    end

    let(:client_b_params) do
      {
        client_id: 'client_b',
        client_secret: 'secret_b',
        org_id: 'org_b@AdobeOrg',
        ims_token_url: 'http://localhost:9292/token_b'
      }
    end

    let(:client_a) { described_class.new(**client_a_params) }
    let(:client_b) { described_class.new(**client_b_params) }

    let(:companies_response_a) do
      jsonapi_list_response(
        type: 'companies',
        items: [
          { id: 'CO_A', attributes: { 'name' => 'Org A Company' } }
        ]
      ).to_json
    end

    let(:companies_response_b) do
      jsonapi_list_response(
        type: 'companies',
        items: [
          { id: 'CO_B', attributes: { 'name' => 'Org B Company' } }
        ]
      ).to_json
    end

    before do
      stub_request(:post, 'http://localhost:9292/token_a')
        .to_return(
          status: 200,
          body: { access_token: 'token_a', expires_in: 86_400 }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )

      stub_request(:post, 'http://localhost:9292/token_b')
        .to_return(
          status: 200,
          body: { access_token: 'token_b', expires_in: 86_400 }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )
    end

    it 'keeps credentials and auth state isolated per client' do
      request_a = stub_request(:get, 'https://reactor.adobe.io/companies?page%5Bsize%5D=100')
                  .with(
                    headers: {
                      'Authorization' => 'Bearer token_a',
                      'x-api-key' => 'client_a',
                      'x-gw-ims-org-id' => 'org_a@AdobeOrg'
                    }
                  ).to_return(
                    status: 200,
                    body: companies_response_a,
                    headers: { 'Content-Type' => 'application/json' }
                  )

      request_b = stub_request(:get, 'https://reactor.adobe.io/companies?page%5Bsize%5D=100')
                  .with(
                    headers: {
                      'Authorization' => 'Bearer token_b',
                      'x-api-key' => 'client_b',
                      'x-gw-ims-org-id' => 'org_b@AdobeOrg'
                    }
                  ).to_return(
                    status: 200,
                    body: companies_response_b,
                    headers: { 'Content-Type' => 'application/json' }
                  )

      result_a = client_a.companies.list
      result_b = client_b.companies.list

      expect(result_a.map(&:id)).to eq(['CO_A'])
      expect(result_b.map(&:id)).to eq(['CO_B'])
      expect(result_a.first.name).to eq('Org A Company')
      expect(result_b.first.name).to eq('Org B Company')
      expect(request_a).to have_been_requested.once
      expect(request_b).to have_been_requested.once
    end
  end
end
