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
end
