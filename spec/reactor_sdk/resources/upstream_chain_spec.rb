# frozen_string_literal: true

##
# @file spec/reactor_sdk/resources/upstream_chain_spec.rb
# @description Tests for ReactorSDK::Resources::UpstreamChain and UpstreamChainEntry.
#

RSpec.describe ReactorSDK::Resources::UpstreamChain do
  let(:library) do
    ReactorSDK::Resources::Library.new(
      id: 'LB_STG',
      type: 'libraries',
      attributes: { 'name' => 'Staging Library', 'state' => 'development' }
    )
  end

  let(:resource) do
    ReactorSDK::Resources::Rule.new(
      id: 'RL123',
      type: 'rules',
      attributes: { 'name' => 'Order Confirmation', 'enabled' => true }
    )
  end

  let(:revision) do
    ReactorSDK::Resources::Revision.new(
      id: 'RE123',
      type: 'revisions',
      attributes: { 'activity_type' => 'updated' },
      included_entity: {
        'id' => 'RL123',
        'type' => 'rules',
        'attributes' => { 'name' => 'Order Confirmation' }
      },
      relationships: {
        'entity' => {
          'data' => { 'id' => 'RL123', 'type' => 'rules' }
        }
      }
    )
  end

  let(:present_entry) do
    ReactorSDK::Resources::UpstreamChainEntry.new(
      library: library,
      stage: 'staging',
      resource: resource,
      revision_id: 'RE123',
      revision: revision
    )
  end

  let(:missing_entry) do
    ReactorSDK::Resources::UpstreamChainEntry.new(
      library: library,
      stage: 'production',
      resource: nil,
      revision_id: nil,
      revision: nil
    )
  end

  describe ReactorSDK::Resources::UpstreamChainEntry do
    it 'reports whether the resource is present in the upstream library' do
      expect(present_entry.present?).to be(true)
      expect(missing_entry.present?).to be(false)
    end

    it 'exposes the upstream entity snapshot when a revision is present' do
      expect(present_entry.entity_snapshot).to eq('name' => 'Order Confirmation')
      expect(missing_entry.entity_snapshot).to be_nil
    end
  end

  describe '#nearest_match and #found?' do
    let(:chain) do
      described_class.new(
        resource_id: 'RL123',
        resource_type: 'rules',
        property_id: 'PR123',
        target_library_id: 'LB_DEV',
        target_resource: resource,
        target_revision_id: 'RE001',
        entries: [missing_entry, present_entry]
      )
    end

    it 'returns the first upstream entry that contains the resource' do
      expect(chain.nearest_match).to eq(present_entry)
    end

    it 'returns true when an upstream match exists' do
      expect(chain.found?).to be(true)
    end

    it 'implements Enumerable over the entries array' do
      expect(chain.map(&:stage)).to eq(%w[production staging])
    end
  end

  describe '#found?' do
    let(:chain) do
      described_class.new(
        resource_id: 'RL123',
        resource_type: 'rules',
        property_id: 'PR123',
        target_library_id: 'LB_DEV',
        target_resource: resource,
        target_revision_id: 'RE001',
        entries: [missing_entry]
      )
    end

    it 'returns false when the resource is absent from all upstream libraries' do
      expect(chain.found?).to be(false)
      expect(chain.nearest_match).to be_nil
    end
  end
end
