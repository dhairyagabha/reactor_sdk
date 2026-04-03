# frozen_string_literal: true

##
# @file spec/reactor_sdk/endpoints/rules_spec.rb
# @description Tests for ReactorSDK::Endpoints::Rules.
#
#   Covers: list, find, create, update, delete,
#   and error handling for not-found and validation failures.
#

RSpec.describe ReactorSDK::Endpoints::Rules do
  subject(:client) { test_client }

  let(:rule_attributes) do
    {
      'name' => 'Order Confirmation',
      'enabled' => true,
      'created_at' => '2024-01-01T00:00:00.000Z',
      'updated_at' => '2024-01-01T00:00:00.000Z',
      'published_at' => nil,
      'revised_at' => nil
    }
  end

  let(:single_response) do
    jsonapi_response(
      type: 'rules',
      id: 'RL123',
      attributes: rule_attributes
    ).to_json
  end

  let(:list_response) do
    jsonapi_list_response(
      type: 'rules',
      items: [
        { id: 'RL123', attributes: rule_attributes },
        { id: 'RL456', attributes: rule_attributes.merge('name' => 'Add to Cart') }
      ]
    ).to_json
  end

  describe '#list_for_property' do
    before do
      stub_request(:get, 'https://reactor.adobe.io/properties/PR123/rules?page%5Bsize%5D=100')
        .to_return(status: 200, body: list_response, headers: { 'Content-Type' => 'application/json' })
    end

    it 'returns an array of Rule resources' do
      result = client.rules.list_for_property('PR123')
      expect(result).to all(be_a(ReactorSDK::Resources::Rule))
    end

    it 'returns the correct number of rules' do
      result = client.rules.list_for_property('PR123')
      expect(result.length).to eq(2)
    end

    it 'maps attributes to Ruby methods' do
      result = client.rules.list_for_property('PR123')
      expect(result.first.name).to eq('Order Confirmation')
      expect(result.first.enabled?).to be(true)
    end

    it 'returns the correct ids' do
      result = client.rules.list_for_property('PR123')
      expect(result.map(&:id)).to eq(%w[RL123 RL456])
    end
  end

  describe '#find' do
    before do
      stub_request(:get, 'https://reactor.adobe.io/rules/RL123')
        .to_return(status: 200, body: single_response, headers: { 'Content-Type' => 'application/json' })
    end

    it 'returns a Rule resource' do
      result = client.rules.find('RL123')
      expect(result).to be_a(ReactorSDK::Resources::Rule)
    end

    it 'maps the id correctly' do
      result = client.rules.find('RL123')
      expect(result.id).to eq('RL123')
    end

    it 'maps attributes to Ruby methods' do
      result = client.rules.find('RL123')
      expect(result.name).to eq('Order Confirmation')
      expect(result.enabled?).to be(true)
    end

    context 'when the rule does not exist' do
      before do
        stub_request(:get, 'https://reactor.adobe.io/rules/RL_INVALID')
          .to_return(status: 404, body: { errors: [] }.to_json)
      end

      it 'raises ResourceNotFoundError' do
        expect do
          client.rules.find('RL_INVALID')
        end.to raise_error(ReactorSDK::ResourceNotFoundError)
      end
    end
  end

  describe '#create' do
    before do
      stub_request(:post, 'https://reactor.adobe.io/properties/PR123/rules')
        .to_return(status: 201, body: single_response, headers: { 'Content-Type' => 'application/json' })
    end

    it 'returns a Rule resource' do
      result = client.rules.create(property_id: 'PR123', name: 'Order Confirmation')
      expect(result).to be_a(ReactorSDK::Resources::Rule)
    end

    it 'maps attributes on the returned resource' do
      result = client.rules.create(property_id: 'PR123', name: 'Order Confirmation')
      expect(result.name).to eq('Order Confirmation')
      expect(result.enabled?).to be(true)
    end

    context 'when attributes are invalid' do
      before do
        stub_request(:post, 'https://reactor.adobe.io/properties/PR123/rules')
          .to_return(
            status: 422,
            body: { errors: [{ detail: "Name can't be blank" }] }.to_json
          )
      end

      it 'raises UnprocessableEntityError' do
        expect do
          client.rules.create(property_id: 'PR123', name: '')
        end.to raise_error(ReactorSDK::UnprocessableEntityError)
      end
    end
  end

  describe '#update' do
    before do
      stub_request(:patch, 'https://reactor.adobe.io/rules/RL123')
        .to_return(
          status: 200,
          body: jsonapi_response(
            type: 'rules',
            id: 'RL123',
            attributes: rule_attributes.merge('name' => 'Updated Rule Name')
          ).to_json,
          headers: { 'Content-Type' => 'application/json' }
        )
    end

    it 'returns the updated Rule resource' do
      result = client.rules.update('RL123', { name: 'Updated Rule Name' })
      expect(result).to be_a(ReactorSDK::Resources::Rule)
    end

    it 'reflects the updated attributes' do
      result = client.rules.update('RL123', { name: 'Updated Rule Name' })
      expect(result.name).to eq('Updated Rule Name')
    end
  end

  describe '#delete' do
    before do
      stub_request(:delete, 'https://reactor.adobe.io/rules/RL123')
        .to_return(status: 204, body: '')
    end

    it 'returns nil on success' do
      result = client.rules.delete('RL123')
      expect(result).to be_nil
    end
  end

  describe 'notes support' do
    before do
      stub_request(:get, 'https://reactor.adobe.io/rules/RL123/notes?page%5Bsize%5D=100')
        .to_return(
          status: 200,
          body: jsonapi_list_response(
            type: 'notes',
            items: [{ id: 'NT123', attributes: { 'text' => 'Rule note' } }]
          ).to_json,
          headers: { 'Content-Type' => 'application/json' }
        )
      stub_request(:get, 'https://reactor.adobe.io/rules/RL123/rule_component_notes?page%5Bsize%5D=100')
        .to_return(
          status: 200,
          body: jsonapi_list_response(
            type: 'rule_components',
            items: [{ id: 'RC123', attributes: { 'name' => 'Send Beacon', 'delegate_descriptor_id' => 'core::actions::custom-code' } }]
          ).to_json,
          headers: { 'Content-Type' => 'application/json' }
        )
    end

    it 'lists direct rule notes' do
      expect(client.rules.list_notes('RL123').first.text).to eq('Rule note')
    end

    it 'lists rule component notes' do
      expect(client.rules.rule_component_notes('RL123').first).to be_a(ReactorSDK::Resources::RuleComponent)
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
                'id' => 'RL123',
                'type' => 'rules',
                'attributes' => { 'name' => 'Order Confirmation', 'enabled' => true },
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
                'id' => 'RL123',
                'type' => 'rules',
                'attributes' => { 'name' => 'Order Confirmation', 'enabled' => true },
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
              'relationships' => { 'entity' => { 'data' => { 'id' => 'RL123', 'type' => 'rules' } } }
            },
            'included' => [
              { 'id' => 'RL123', 'type' => 'rules', 'attributes' => { 'name' => 'Order Confirmation', 'enabled' => true } }
            ]
          }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )
    end

    it 'returns an UpstreamChain for the rule' do
      result = client.rules.upstream_chain('RL123', library_id: 'LB_DEV', property_id: 'PR123')

      expect(result).to be_a(ReactorSDK::Resources::UpstreamChain)
      expect(result.resource_type).to eq('rules')
      expect(result.nearest_match.library.id).to eq('LB_STG')
    end
  end

  describe '#find_comprehensive' do
    let(:snapshot) { instance_double(ReactorSDK::Resources::LibrarySnapshot) }
    let(:libraries_endpoint) { instance_double(ReactorSDK::Endpoints::Libraries) }
    let(:comprehensive_rule) do
      ReactorSDK::Resources::ComprehensiveRule.new(
        resource: ReactorSDK::Resources::Rule.new(
          id: 'RL123',
          type: 'rules',
          attributes: { 'name' => 'Order Confirmation', 'enabled' => true }
        ),
        rule_components: []
      )
    end

    before do
      allow(client.rules).to receive(:libraries_endpoint).and_return(libraries_endpoint)
      allow(libraries_endpoint)
        .to receive(:find_snapshot)
        .with('LB_DEV', property_id: 'PR123')
        .and_return(snapshot)
    end

    it 'returns the comprehensive rule from the snapshot' do
      allow(snapshot).to receive(:comprehensive_resource)
        .with('RL123', resource_type: 'rules')
        .and_return(comprehensive_rule)

      expect(client.rules.find_comprehensive('RL123', library_id: 'LB_DEV', property_id: 'PR123')).to eq(comprehensive_rule)
    end

    it 'raises ResourceNotFoundError when the rule is missing from the snapshot' do
      allow(snapshot).to receive(:comprehensive_resource)
        .with('RL123', resource_type: 'rules')
        .and_return(nil)

      expect do
        client.rules.find_comprehensive('RL123', library_id: 'LB_DEV', property_id: 'PR123')
      end.to raise_error(ReactorSDK::ResourceNotFoundError)
    end
  end

  describe '#comprehensive_upstream_chain' do
    it 'delegates to the Libraries endpoint helper' do
      chain = instance_double(ReactorSDK::Resources::ComprehensiveUpstreamChain)
      libraries_endpoint = instance_double(ReactorSDK::Endpoints::Libraries)

      allow(client.rules).to receive(:libraries_endpoint).and_return(libraries_endpoint)
      allow(libraries_endpoint)
        .to receive(:comprehensive_upstream_chain_for_resource)
        .with('RL123', library_id: 'LB_DEV', property_id: 'PR123', resource_type: 'rules')
        .and_return(chain)

      expect(client.rules.comprehensive_upstream_chain('RL123', library_id: 'LB_DEV', property_id: 'PR123')).to eq(chain)
    end
  end
end
