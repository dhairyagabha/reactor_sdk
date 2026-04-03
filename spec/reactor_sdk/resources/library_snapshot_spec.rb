# frozen_string_literal: true

RSpec.describe ReactorSDK::Resources::LibrarySnapshot do
  def raw_resource(id:, type:, attributes:, revision_id: nil, relationships: {})
    relationship_hash = relationships.dup
    if revision_id
      relationship_hash['latest_revision'] = {
        'data' => { 'id' => revision_id, 'type' => 'revisions' }
      }
    end

    {
      'id' => id,
      'type' => type,
      'attributes' => attributes,
      'relationships' => relationship_hash
    }
  end

  def build_component(id:, name:, delegate:, settings:, extension_id:, order:, rule_order:, revision_id: nil)
    ReactorSDK::Resources::RuleComponent.new(
      id: id,
      type: 'rule_components',
      attributes: {
        'name' => name,
        'delegate_descriptor_id' => delegate,
        'settings' => settings,
        'order' => order,
        'rule_order' => rule_order
      },
      relationships: {
        'extension' => { 'data' => { 'id' => extension_id, 'type' => 'extensions' } },
        'latest_revision' => revision_id ? { 'data' => { 'id' => revision_id, 'type' => 'revisions' } } : nil
      }.compact
    )
  end

  subject(:snapshot) do
    described_class.new(
      property_id: 'PR123',
      library: library,
      rule_components_by_rule_id: rule_components_by_rule_id
    )
  end

  let(:library) do
    ReactorSDK::Resources::LibraryWithResources.new(
      id: 'LB123',
      type: 'libraries',
      attributes: {
        'name' => 'Dev Library',
        'state' => 'development',
        'published' => false
      },
      included_resources: {
        'rules' => [
          raw_resource(
            id: 'RL100',
            type: 'rules',
            revision_id: 'RE_RL100',
            attributes: { 'name' => 'Page View', 'enabled' => true }
          ),
          raw_resource(
            id: 'RL200',
            type: 'rules',
            revision_id: 'RE_RL200',
            attributes: { 'name' => 'Cart Rule', 'enabled' => true }
          ),
          raw_resource(
            id: 'RL300',
            type: 'rules',
            revision_id: 'RE_RL300',
            attributes: { 'name' => 'Lowercase Rule', 'enabled' => true }
          )
        ],
        'data_elements' => [
          raw_resource(
            id: 'DE100',
            type: 'data_elements',
            revision_id: 'RE_DE100',
            attributes: {
              'name' => 'Page Name',
              'delegate_descriptor_id' => 'core::dataElements::custom-code',
              'settings' => JSON.generate({ 'source' => 'return document.title;' })
            },
            relationships: {
              'extension' => { 'data' => { 'id' => 'EX_CORE', 'type' => 'extensions' } }
            }
          ),
          raw_resource(
            id: 'DE200',
            type: 'data_elements',
            revision_id: 'RE_DE200',
            attributes: {
              'name' => 'Product Name',
              'delegate_descriptor_id' => 'core::dataElements::custom-code',
              'settings' => JSON.generate({ 'source' => "return _satellite.getVar('Page Name');" })
            },
            relationships: {
              'extension' => { 'data' => { 'id' => 'EX_CORE', 'type' => 'extensions' } }
            }
          ),
          raw_resource(
            id: 'DE300',
            type: 'data_elements',
            revision_id: 'RE_DE300',
            attributes: {
              'name' => 'Cart Name',
              'delegate_descriptor_id' => 'core::dataElements::custom-code',
              'settings' => JSON.generate({ 'source' => 'return "%Product Name%";' })
            },
            relationships: {
              'extension' => { 'data' => { 'id' => 'EX_CORE', 'type' => 'extensions' } }
            }
          )
        ],
        'extensions' => [
          raw_resource(
            id: 'EX_CORE',
            type: 'extensions',
            revision_id: 'RE_EX_CORE',
            attributes: {
              'name' => 'Core',
              'delegate_descriptor_id' => 'core::extension',
              'settings' => '{}'
            }
          ),
          raw_resource(
            id: 'EX_ALLOY',
            type: 'extensions',
            revision_id: 'RE_EX_ALLOY',
            attributes: {
              'name' => 'Adobe Web SDK',
              'delegate_descriptor_id' => 'adobe-alloy::extension',
              'settings' => JSON.generate({ 'edgeDomain' => 'example.sc.omtrdc.net' })
            }
          )
        ]
      }
    )
  end

  let(:rule_components_by_rule_id) do
    {
      'RL100' => [
        build_component(
          id: 'RC110',
          name: 'Custom Code',
          delegate: 'core::actions::custom-code',
          settings: JSON.generate({ 'source' => "console.log(_satellite.getVar('Page Name'));", 'language' => 'javascript' }),
          extension_id: 'EX_CORE',
          order: 2,
          rule_order: 50.0,
          revision_id: 'RE_RC110'
        ),
        build_component(
          id: 'RC100',
          name: 'Send Event',
          delegate: 'adobe-alloy::actions::send-event',
          settings: JSON.generate({ 'xdm' => { 'web' => { 'webPageDetails' => { 'name' => '%Page Name%' } } } }),
          extension_id: 'EX_ALLOY',
          order: 1,
          rule_order: 10.0,
          revision_id: 'RE_RC100'
        )
      ],
      'RL200' => [
        build_component(
          id: 'RC200',
          name: 'Cart Action',
          delegate: 'core::actions::custom-code',
          settings: JSON.generate({ 'source' => "console.log(_satellite.getVar('Cart Name'));", 'language' => 'javascript' }),
          extension_id: 'EX_CORE',
          order: 1,
          rule_order: 20.0,
          revision_id: 'RE_RC200'
        ),
        build_component(
          id: 'RC201',
          name: 'Lowercase Reference',
          delegate: 'core::actions::custom-code',
          settings: JSON.generate({ 'source' => "console.log(_satellite.getVar('page name'));", 'language' => 'javascript' }),
          extension_id: 'EX_CORE',
          order: 2,
          rule_order: 20.0,
          revision_id: 'RE_RC201'
        )
      ],
      'RL300' => [
        build_component(
          id: 'RC300',
          name: 'Lowercase Reference',
          delegate: 'core::actions::custom-code',
          settings: JSON.generate({ 'source' => "console.log(_satellite.getVar('page name'));", 'language' => 'javascript' }),
          extension_id: 'EX_CORE',
          order: 1,
          rule_order: 20.0,
          revision_id: 'RE_RC300'
        )
      ]
    }
  end

  describe '#rule_components_for_rule' do
    it 'sorts rule components by rule_order, order, and id' do
      expect(snapshot.rule_components_for_rule('RL100').map(&:id)).to eq(%w[RC100 RC110])
    end
  end

  describe '#referenced_data_elements_for' do
    it 'returns direct data element dependencies from Launch syntax' do
      expect(snapshot.referenced_data_elements_for('DE200').map(&:id)).to eq(['DE100'])
      expect(snapshot.referenced_data_elements_for('DE300').map(&:id)).to eq(['DE200'])
    end
  end

  describe '#impacted_rules_for' do
    it 'returns directly impacted rules' do
      expect(snapshot.impacted_rules_for('DE300').map(&:id)).to eq(['RL200'])
    end

    it 'returns transitively impacted rules through nested data elements' do
      expect(snapshot.impacted_rules_for('DE100').map(&:id)).to eq(%w[RL200 RL100])
    end

    it 'keeps matching case-sensitive' do
      expect(snapshot.impacted_rules_for('DE100').map(&:id)).not_to include('RL300')
    end
  end

  describe '#comprehensive_resource' do
    it 'builds a comprehensive rule with its components' do
      comprehensive = snapshot.comprehensive_resource('RL100', resource_type: 'rules')

      expect(comprehensive).to be_a(ReactorSDK::Resources::ComprehensiveRule)
      expect(comprehensive.rule_components.map(&:id)).to eq(%w[RC100 RC110])
      expect(comprehensive.normalized_payload.dig('associations', 'rule_components').map { |item| item['id'] }).to eq(%w[RC100 RC110])
    end

    it 'builds a comprehensive data element with impacted rules' do
      comprehensive = snapshot.comprehensive_resource('DE100', resource_type: 'data_elements')

      expect(comprehensive).to be_a(ReactorSDK::Resources::ComprehensiveDataElement)
      expect(comprehensive.referenced_data_elements).to eq([])
      expect(comprehensive.impacted_rules.map(&:id)).to eq(%w[RL200 RL100])
    end

    it 'builds a comprehensive extension with dependent resources' do
      comprehensive = snapshot.comprehensive_resource('EX_CORE', resource_type: 'extensions')

      expect(comprehensive).to be_a(ReactorSDK::Resources::ComprehensiveExtension)
      expect(comprehensive.data_elements.map(&:id)).to eq(%w[DE300 DE100 DE200])
      expect(comprehensive.rule_components.map(&:id)).to eq(%w[RC200 RC300 RC201 RC110])
      expect(comprehensive.rules.map(&:id)).to eq(%w[RL200 RL300 RL100])
    end
  end

  describe '#resource_revision_id' do
    it 'returns revision ids for top-level resources and rule components' do
      expect(snapshot.resource_revision_id('DE100')).to eq('RE_DE100')
      expect(snapshot.resource_revision_id('RC100')).to eq('RE_RC100')
    end
  end
end
