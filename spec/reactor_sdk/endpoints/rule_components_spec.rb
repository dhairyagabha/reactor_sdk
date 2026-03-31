# frozen_string_literal: true

##
# @file spec/reactor_sdk/endpoints/rule_components_spec.rb
# @description Tests for ReactorSDK::Endpoints::RuleComponents.
#
#   Covers: list, find, create, update, delete, and error handling.
#

RSpec.describe ReactorSDK::Endpoints::RuleComponents do
  subject(:client) { test_client }

  let(:rule_component_attributes) do
    {
      'name' => 'Send Beacon',
      'delegate_descriptor_id' => 'adobe-analytics::actions::send-beacon',
      'settings' => { trackerProperties: { events: ['event1'] } }.to_json,
      'order' => 1,
      'created_at' => '2024-01-01T00:00:00.000Z',
      'updated_at' => '2024-01-02T00:00:00.000Z'
    }
  end

  let(:single_response) do
    jsonapi_response(
      type: 'rule_components',
      id: 'RC123',
      attributes: rule_component_attributes
    ).to_json
  end

  let(:list_response) do
    jsonapi_list_response(
      type: 'rule_components',
      items: [
        { id: 'RC123', attributes: rule_component_attributes },
        { id: 'RC456', attributes: rule_component_attributes.merge('name' => 'Set Variables') }
      ]
    ).to_json
  end

  describe '#list_for_rule' do
    before do
      stub_request(:get, 'https://reactor.adobe.io/rules/RL123/rule_components?page%5Bsize%5D=100')
        .to_return(status: 200, body: list_response, headers: { 'Content-Type' => 'application/json' })
    end

    it 'returns an array of RuleComponent resources' do
      result = client.rule_components.list_for_rule('RL123')
      expect(result).to all(be_a(ReactorSDK::Resources::RuleComponent))
    end

    it 'returns the correct number of rule components' do
      result = client.rule_components.list_for_rule('RL123')
      expect(result.length).to eq(2)
    end

    it 'maps attributes to Ruby methods' do
      result = client.rule_components.list_for_rule('RL123')
      expect(result.first.name).to eq('Send Beacon')
      expect(result.first.delegate_descriptor_id).to eq('adobe-analytics::actions::send-beacon')
      expect(result.first.order).to eq(1)
    end
  end

  describe '#find' do
    before do
      stub_request(:get, 'https://reactor.adobe.io/rule_components/RC123')
        .to_return(status: 200, body: single_response, headers: { 'Content-Type' => 'application/json' })
    end

    it 'returns a RuleComponent resource' do
      result = client.rule_components.find('RC123')
      expect(result).to be_a(ReactorSDK::Resources::RuleComponent)
    end

    it 'maps the id correctly' do
      result = client.rule_components.find('RC123')
      expect(result.id).to eq('RC123')
    end

    context 'when the rule component does not exist' do
      before do
        stub_request(:get, 'https://reactor.adobe.io/rule_components/RC_INVALID')
          .to_return(status: 404, body: { errors: [] }.to_json)
      end

      it 'raises ResourceNotFoundError' do
        expect do
          client.rule_components.find('RC_INVALID')
        end.to raise_error(ReactorSDK::ResourceNotFoundError)
      end
    end
  end

  describe '#create' do
    before do
      stub_request(:post, 'https://reactor.adobe.io/properties/PR123/rule_components')
        .to_return(status: 201, body: single_response, headers: { 'Content-Type' => 'application/json' })
    end

    it 'returns a RuleComponent resource' do
      result = client.rule_components.create(
        property_id: 'PR123',
        rule_id: 'RL123',
        name: 'Send Beacon',
        delegate_descriptor_id: 'adobe-analytics::actions::send-beacon',
        settings: { trackerProperties: { events: ['event1'] } }.to_json,
        extension_id: 'EX123'
      )
      expect(result).to be_a(ReactorSDK::Resources::RuleComponent)
    end

    it 'sends the correct payload including extension and rule relationships' do
      client.rule_components.create(
        property_id: 'PR123',
        rule_id: 'RL123',
        name: 'Send Beacon',
        delegate_descriptor_id: 'adobe-analytics::actions::send-beacon',
        settings: { trackerProperties: { events: ['event1'] } }.to_json,
        extension_id: 'EX123'
      )

      expect(WebMock).to have_requested(:post, 'https://reactor.adobe.io/properties/PR123/rule_components')
        .with(body: {
          data: {
            type: 'rule_components',
            attributes: {
              name: 'Send Beacon',
              delegate_descriptor_id: 'adobe-analytics::actions::send-beacon',
              settings: { trackerProperties: { events: ['event1'] } }.to_json,
              rule_order: 50.0,
              order: 0
            },
            relationships: {
              extension: {
                data: { id: 'EX123', type: 'extensions' }
              },
              rules: {
                data: [{ id: 'RL123', type: 'rules' }]
              }
            }
          }
        }.to_json)
    end
  end

  describe '#update' do
    before do
      stub_request(:patch, 'https://reactor.adobe.io/rule_components/RC123')
        .to_return(
          status: 200,
          body: jsonapi_response(
            type: 'rule_components',
            id: 'RC123',
            attributes: rule_component_attributes.merge('name' => 'Updated Beacon')
          ).to_json,
          headers: { 'Content-Type' => 'application/json' }
        )
    end

    it 'returns the updated RuleComponent resource' do
      result = client.rule_components.update('RC123', { name: 'Updated Beacon' })
      expect(result).to be_a(ReactorSDK::Resources::RuleComponent)
    end

    it 'reflects the updated attributes' do
      result = client.rule_components.update('RC123', { name: 'Updated Beacon' })
      expect(result.name).to eq('Updated Beacon')
    end
  end

  describe '#delete' do
    before do
      stub_request(:delete, 'https://reactor.adobe.io/rule_components/RC123')
        .to_return(status: 204, body: '')
    end

    it 'returns nil on success' do
      result = client.rule_components.delete('RC123')
      expect(result).to be_nil
    end
  end
end
