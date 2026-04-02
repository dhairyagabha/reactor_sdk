# frozen_string_literal: true

##
# @file spec/reactor_sdk/resources/base_resource_spec.rb
# @description Direct tests for ReactorSDK::Resources::BaseResource.
#
#   Covers the attribute macro, boolean aliases, defaults, hash-style
#   access, equality semantics, serialization, and inspect output.
#

RSpec.describe ReactorSDK::Resources::BaseResource do
  subject(:resource) do
    resource_class.new(
      id: 'PR123',
      type: 'properties',
      attributes: {
        'name' => 'Marketing Site',
        'enabled' => true
      },
      meta: { 'page' => 1 }
    )
  end

  let(:resource_class) do
    stub_const(
      'SpecBaseResource',
      Class.new(described_class) do
        attribute :name
        attribute :enabled, as: :boolean
        attribute :domains, default: []
      end
    )
  end

  describe '.attribute' do
    it 'defines reader methods for declared attributes' do
      expect(resource.name).to eq('Marketing Site')
    end

    it 'defines boolean predicate aliases' do
      expect(resource.enabled?).to be(true)
    end

    it 'returns default values for missing attributes' do
      expect(resource.domains).to eq([])
    end

    it 'casts nil booleans to false for predicate methods' do
      disabled_resource = resource_class.new(id: 'PR456', type: 'properties')

      expect(disabled_resource.enabled?).to be(false)
    end
  end

  describe '#[]' do
    it 'supports string keys' do
      expect(resource['name']).to eq('Marketing Site')
    end

    it 'supports symbol keys' do
      expect(resource[:name]).to eq('Marketing Site')
    end
  end

  describe '#==' do
    it 'compares resources by id and type' do
      same_resource = resource_class.new(
        id: 'PR123',
        type: 'properties',
        attributes: { 'name' => 'Renamed Property' }
      )

      expect(resource).to eq(same_resource)
    end

    it 'returns false for different resource identities' do
      other_resource = resource_class.new(id: 'PR999', type: 'properties')

      expect(resource).not_to eq(other_resource)
    end
  end

  describe '#to_h' do
    it 'returns a plain hash representation' do
      expect(resource.to_h).to eq(
        id: 'PR123',
        type: 'properties',
        attributes: {
          'name' => 'Marketing Site',
          'enabled' => true
        },
        meta: { 'page' => 1 }
      )
    end
  end

  describe '#inspect' do
    it 'includes the class name, id, and type' do
      expect(resource.inspect).to include('SpecBaseResource')
      expect(resource.inspect).to include('"PR123"')
      expect(resource.inspect).to include('"properties"')
    end
  end
end
