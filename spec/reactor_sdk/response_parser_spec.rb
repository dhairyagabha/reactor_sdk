# frozen_string_literal: true

##
# @file spec/reactor_sdk/response_parser_spec.rb
# @description Direct tests for ReactorSDK::ResponseParser.
#
#   Covers standard resource parsing, revision-specific parsing with
#   included entity snapshots, and list parsing behavior.
#

RSpec.describe ReactorSDK::ResponseParser do
  subject(:parser) { described_class.new }

  describe '#parse' do
    it 'builds a typed resource with attributes and meta' do
      resource = parser.parse(
        {
          'id' => 'PR123',
          'type' => 'properties',
          'attributes' => { 'name' => 'Marketing Site' },
          'meta' => { 'page' => 1 },
          'relationships' => {
            'company' => { 'data' => { 'id' => 'CO123', 'type' => 'companies' } }
          }
        },
        ReactorSDK::Resources::Property
      )

      expect(resource).to be_a(ReactorSDK::Resources::Property)
      expect(resource.id).to eq('PR123')
      expect(resource.name).to eq('Marketing Site')
      expect(resource.meta).to eq('page' => 1)
      expect(resource.relationship_id('company')).to eq('CO123')
    end

    it 'raises ArgumentError when data is nil' do
      expect do
        parser.parse(nil, ReactorSDK::Resources::Property)
      end.to raise_error(ArgumentError, 'data cannot be nil')
    end

    it 'extracts revision snapshot data from the full response' do
      revision = parser.parse(
        {
          'id' => 'RE123',
          'type' => 'revisions',
          'attributes' => { 'activity_type' => 'updated' },
          'relationships' => {
            'entity' => {
              'data' => { 'id' => 'RL123', 'type' => 'rules' }
            }
          }
        },
        ReactorSDK::Resources::Revision,
        response: {
          'included' => [
            {
              'id' => 'RL123',
              'type' => 'rules',
              'attributes' => { 'name' => 'Order Confirmation', 'enabled' => true }
            }
          ]
        }
      )

      expect(revision.entity_id).to eq('RL123')
      expect(revision.entity_type).to eq('rules')
      expect(revision.entity_snapshot).to eq(
        'name' => 'Order Confirmation',
        'enabled' => true
      )
    end

    it 'retains included entity relationships on the revision' do
      revision = parser.parse(
        {
          'id' => 'RE123',
          'type' => 'revisions',
          'attributes' => { 'activity_type' => 'updated' },
          'relationships' => {
            'entity' => {
              'data' => { 'id' => 'RL123', 'type' => 'rules' }
            }
          }
        },
        ReactorSDK::Resources::Revision,
        response: {
          'included' => [
            {
              'id' => 'RL123',
              'type' => 'rules',
              'attributes' => { 'name' => 'Order Confirmation' },
              'relationships' => {
                'rule_components' => {
                  'data' => [{ 'id' => 'RC123', 'type' => 'rule_components' }]
                }
              }
            }
          ]
        }
      )

      expect(revision.entity_relationships).to eq(
        'rule_components' => {
          'data' => [{ 'id' => 'RC123', 'type' => 'rule_components' }]
        }
      )
    end
  end

  describe '#parse_many' do
    it 'returns an empty array when data_array is nil' do
      expect(parser.parse_many(nil, ReactorSDK::Resources::Property)).to eq([])
    end

    it 'parses each record in the collection' do
      resources = parser.parse_many(
        [
          {
            'id' => 'PR123',
            'type' => 'properties',
            'attributes' => { 'name' => 'Marketing Site' }
          },
          {
            'id' => 'PR456',
            'type' => 'properties',
            'attributes' => { 'name' => 'Checkout Site' }
          }
        ],
        ReactorSDK::Resources::Property
      )

      expect(resources.map(&:id)).to eq(%w[PR123 PR456])
      expect(resources.map(&:name)).to eq(['Marketing Site', 'Checkout Site'])
    end
  end
end
