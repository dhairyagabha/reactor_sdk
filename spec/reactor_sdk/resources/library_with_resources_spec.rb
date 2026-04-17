# frozen_string_literal: true

##
# @file spec/reactor_sdk/resources/library_with_resources_spec.rb
# @description Tests for ReactorSDK::Resources::LibraryWithResources.
#
#   Covers: attribute mapping, included resource parsing, revision_id
#   attachment, resource_index, all_resources, empty included arrays,
#   and missing relationship data.
#

RSpec.describe ReactorSDK::Resources::LibraryWithResources do
  # ── Helpers ──────────────────────────────────────────────────

  ##
  # Builds a raw JSON:API resource hash with optional revision relationship.
  #
  def raw_resource(id:, type:, attributes: {}, revision_id: nil)
    hash = {
      'id' => id,
      'type' => type,
      'attributes' => attributes
    }
    if revision_id
      hash['relationships'] = {
        'latest_revision' => { 'data' => { 'id' => revision_id, 'type' => 'revisions' } }
      }
    end
    hash
  end

  ##
  # Builds a LibraryWithResources with given included resources.
  #
  def build_library(included_resources: {})
    described_class.new(
      id: 'LB123',
      type: 'libraries',
      attributes: {
        'name' => 'Release 1.0',
        'state' => 'development',
        'published' => false,
        'created_at' => '2024-01-01T00:00:00.000Z',
        'updated_at' => '2024-01-02T00:00:00.000Z'
      },
      included_resources: included_resources
    )
  end

  # ── Attribute mapping ────────────────────────────────────────

  describe 'attribute mapping' do
    subject(:library) { build_library }

    it { expect(library.id).to eq('LB123') }
    it { expect(library.name).to eq('Release 1.0') }
    it { expect(library.state).to eq('development') }
    it { expect(library.published?).to be(false) }
    it { expect(library.buildable?).to be(true) }
    it { expect(library.created_at).to eq('2024-01-01T00:00:00.000Z') }
    it { expect(library.updated_at).to eq('2024-01-02T00:00:00.000Z') }
  end

  # ── buildable? and published? ────────────────────────────────

  describe '#buildable? and #published?' do
    it 'is buildable when state is development' do
      library = described_class.new(
        id: 'LB1', type: 'libraries',
        attributes: { 'state' => 'development' }
      )
      expect(library.buildable?).to be(true)
    end

    it 'is not buildable when state is published' do
      library = described_class.new(
        id: 'LB1', type: 'libraries',
        attributes: { 'state' => 'published' }
      )
      expect(library.buildable?).to be(false)
    end

    it 'is published when state is published' do
      library = described_class.new(
        id: 'LB1', type: 'libraries',
        attributes: { 'state' => 'published' }
      )
      expect(library.published?).to be(true)
    end
  end

  describe 'key normalization' do
    it 'supports symbol-keyed attributes and included resources' do
      library = described_class.new(
        id: 'LB123',
        type: 'libraries',
        attributes: {
          name: 'Release 1.0',
          state: 'development'
        },
        included_resources: {
          rules: [
            {
              id: 'RL123',
              type: 'rules',
              attributes: { name: 'Order Confirmation', enabled: true },
              relationships: {
                latest_revision: {
                  data: { id: 'RE001', type: 'revisions' }
                }
              }
            }
          ]
        }
      )

      expect(library.name).to eq('Release 1.0')
      expect(library.rules.length).to eq(1)
      expect(library.rules.first.name).to eq('Order Confirmation')
      expect(library.rules.first.revision_id).to eq('RE001')
    end
  end

  # ── Rules ────────────────────────────────────────────────────

  describe '#rules' do
    context 'with rules in the included array' do
      let(:library) do
        build_library(included_resources: {
                        'rules' => [
                          raw_resource(id: 'RL123', type: 'rules',
                                       attributes: { 'name' => 'Order Confirmation', 'enabled' => true },
                                       revision_id: 'RE001'),
                          raw_resource(id: 'RL456', type: 'rules',
                                       attributes: { 'name' => 'Add to Cart', 'enabled' => false },
                                       revision_id: 'RE002')
                        ]
                      })
      end

      it 'returns an array of Rule resources' do
        expect(library.rules).to all(be_a(ReactorSDK::Resources::Rule))
      end

      it 'returns the correct number of rules' do
        expect(library.rules.length).to eq(2)
      end

      it 'maps rule attributes correctly' do
        expect(library.rules.first.name).to eq('Order Confirmation')
        expect(library.rules.first.enabled?).to be(true)
      end

      it 'attaches revision_id to each rule' do
        expect(library.rules.first.revision_id).to eq('RE001')
        expect(library.rules.last.revision_id).to eq('RE002')
      end

      it 'returns correct rule ids' do
        expect(library.rules.map(&:id)).to eq(%w[RL123 RL456])
      end
    end

    context 'when no rules are included' do
      it 'returns an empty array' do
        expect(build_library.rules).to eq([])
      end
    end

    context 'when a rule has no revision relationship' do
      it 'returns nil for revision_id' do
        library = build_library(included_resources: {
                                  'rules' => [
                                    raw_resource(id: 'RL123', type: 'rules',
                                                 attributes: { 'name' => 'No Revision Rule' })
                                  ]
                                })
        expect(library.rules.first.revision_id).to be_nil
      end
    end
  end

  # ── Data elements ────────────────────────────────────────────

  describe '#data_elements' do
    context 'with data elements in the included array' do
      let(:library) do
        build_library(included_resources: {
                        'data_elements' => [
                          raw_resource(id: 'DE123', type: 'data_elements',
                                       attributes: { 'name' => 'Page Name' },
                                       revision_id: 'RE010')
                        ]
                      })
      end

      it 'returns an array of DataElement resources' do
        expect(library.data_elements).to all(be_a(ReactorSDK::Resources::DataElement))
      end

      it 'maps data element attributes correctly' do
        expect(library.data_elements.first.name).to eq('Page Name')
      end

      it 'attaches revision_id to each data element' do
        expect(library.data_elements.first.revision_id).to eq('RE010')
      end
    end

    context 'when no data elements are included' do
      it 'returns an empty array' do
        expect(build_library.data_elements).to eq([])
      end
    end
  end

  # ── Extensions ───────────────────────────────────────────────

  describe '#extensions' do
    context 'with extensions in the included array' do
      let(:library) do
        build_library(included_resources: {
                        'extensions' => [
                          raw_resource(id: 'EX123', type: 'extensions',
                                       attributes: { 'name' => 'Adobe Analytics' },
                                       revision_id: 'RE020')
                        ]
                      })
      end

      it 'returns an array of Extension resources' do
        expect(library.extensions).to all(be_a(ReactorSDK::Resources::Extension))
      end

      it 'maps extension attributes correctly' do
        expect(library.extensions.first.name).to eq('Adobe Analytics')
      end

      it 'attaches revision_id to each extension' do
        expect(library.extensions.first.revision_id).to eq('RE020')
      end
    end

    context 'when no extensions are included' do
      it 'returns an empty array' do
        expect(build_library.extensions).to eq([])
      end
    end
  end

  # ── resource_index ───────────────────────────────────────────

  describe '#resource_index' do
    context 'with rules, data elements, and extensions' do
      let(:library) do
        build_library(included_resources: {
                        'rules' => [
                          raw_resource(id: 'RL123', type: 'rules',
                                       attributes: {}, revision_id: 'RE001'),
                          raw_resource(id: 'RL456', type: 'rules',
                                       attributes: {}, revision_id: 'RE002')
                        ],
                        'data_elements' => [
                          raw_resource(id: 'DE123', type: 'data_elements',
                                       attributes: {}, revision_id: 'RE010')
                        ],
                        'extensions' => [
                          raw_resource(id: 'EX123', type: 'extensions',
                                       attributes: {}, revision_id: 'RE020')
                        ]
                      })
      end

      it 'returns a Hash keyed by resource ID with revision ID values' do
        index = library.resource_index
        expect(index['RL123']).to eq('RE001')
        expect(index['RL456']).to eq('RE002')
        expect(index['DE123']).to eq('RE010')
        expect(index['EX123']).to eq('RE020')
      end

      it 'includes all resource types in a single index' do
        expect(library.resource_index.length).to eq(4)
      end
    end

    context 'when a resource has no revision_id' do
      it 'excludes that resource from the index' do
        library = build_library(included_resources: {
                                  'rules' => [
                                    raw_resource(id: 'RL123', type: 'rules', attributes: {}, revision_id: 'RE001'),
                                    raw_resource(id: 'RL456', type: 'rules', attributes: {})
                                  ]
                                })
        index = library.resource_index
        expect(index.key?('RL123')).to be(true)
        expect(index.key?('RL456')).to be(false)
      end
    end

    context 'when no resources are included' do
      it 'returns an empty Hash' do
        expect(build_library.resource_index).to eq({})
      end
    end
  end

  # ── all_resources ────────────────────────────────────────────

  describe '#all_resources' do
    it 'returns all resource types as a flat array' do
      library = build_library(included_resources: {
                                'rules' => [raw_resource(id: 'RL1', type: 'rules', attributes: {})],
                                'data_elements' => [raw_resource(id: 'DE1', type: 'data_elements', attributes: {})],
                                'extensions' => [raw_resource(id: 'EX1', type: 'extensions', attributes: {})]
                              })
      expect(library.all_resources.length).to eq(3)
      expect(library.all_resources.map(&:id)).to contain_exactly('RL1', 'DE1', 'EX1')
    end

    it 'returns an empty array when no resources are included' do
      expect(build_library.all_resources).to eq([])
    end
  end

  # ── inspect ──────────────────────────────────────────────────

  describe '#inspect' do
    it 'includes id, name, state and resource counts' do
      library = build_library(included_resources: {
                                'rules' => [raw_resource(id: 'RL1', type: 'rules', attributes: {})],
                                'data_elements' => [],
                                'extensions' => [raw_resource(id: 'EX1', type: 'extensions', attributes: {})]
                              })
      expect(library.inspect).to include('LB123')
      expect(library.inspect).to include('Release 1.0')
      expect(library.inspect).to include('development')
      expect(library.inspect).to include('rules=1')
      expect(library.inspect).to include('data_elements=0')
      expect(library.inspect).to include('extensions=1')
    end
  end
end
