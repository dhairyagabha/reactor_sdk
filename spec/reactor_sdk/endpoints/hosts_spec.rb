# frozen_string_literal: true

##
# @file spec/reactor_sdk/endpoints/hosts_spec.rb
# @description Tests for ReactorSDK::Endpoints::Hosts.
#
#   Covers: list_for_property, find, and Host resource methods.
#

RSpec.describe ReactorSDK::Endpoints::Hosts do
  subject(:client) { test_client }

  let(:host_attributes) do
    {
      'name' => 'Adobe Managed CDN',
      'type_of' => 'akamai',
      'status' => 'succeeded',
      'created_at' => '2024-01-01T00:00:00.000Z',
      'updated_at' => '2024-01-01T00:00:00.000Z'
    }
  end

  let(:single_response) do
    jsonapi_response(
      type: 'hosts',
      id: 'HT123',
      attributes: host_attributes
    ).to_json
  end

  let(:list_response) do
    jsonapi_list_response(
      type: 'hosts',
      items: [{ id: 'HT123', attributes: host_attributes }]
    ).to_json
  end

  describe '#list_for_property' do
    before do
      stub_request(:get, 'https://reactor.adobe.io/properties/PR123/hosts?page%5Bsize%5D=100')
        .to_return(status: 200, body: list_response, headers: { 'Content-Type' => 'application/json' })
    end

    it 'returns an array of Host resources' do
      result = client.hosts.list_for_property('PR123')
      expect(result).to all(be_a(ReactorSDK::Resources::Host))
    end

    it 'returns the correct number of hosts' do
      result = client.hosts.list_for_property('PR123')
      expect(result.length).to eq(1)
    end

    it 'maps attributes to Ruby methods' do
      result = client.hosts.list_for_property('PR123')
      expect(result.first.name).to eq('Adobe Managed CDN')
      expect(result.first.type_of).to eq('akamai')
      expect(result.first.status).to eq('succeeded')
    end

    it 'akamai? returns true for akamai hosts' do
      result = client.hosts.list_for_property('PR123')
      expect(result.first.akamai?).to be(true)
    end

    it 'ready? returns true for succeeded hosts' do
      result = client.hosts.list_for_property('PR123')
      expect(result.first.ready?).to be(true)
    end
  end

  describe '#find' do
    before do
      stub_request(:get, 'https://reactor.adobe.io/hosts/HT123')
        .to_return(status: 200, body: single_response, headers: { 'Content-Type' => 'application/json' })
    end

    it 'returns a Host resource' do
      result = client.hosts.find('HT123')
      expect(result).to be_a(ReactorSDK::Resources::Host)
    end

    it 'maps the id correctly' do
      result = client.hosts.find('HT123')
      expect(result.id).to eq('HT123')
    end

    it 'maps attributes to Ruby methods' do
      result = client.hosts.find('HT123')
      expect(result.name).to eq('Adobe Managed CDN')
      expect(result.type_of).to eq('akamai')
    end

    context 'when the host does not exist' do
      before do
        stub_request(:get, 'https://reactor.adobe.io/hosts/HT_INVALID')
          .to_return(status: 404, body: { errors: [] }.to_json)
      end

      it 'raises ResourceNotFoundError' do
        expect do
          client.hosts.find('HT_INVALID')
        end.to raise_error(ReactorSDK::ResourceNotFoundError)
      end
    end
  end
end
