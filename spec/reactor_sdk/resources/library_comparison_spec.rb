# frozen_string_literal: true

RSpec.describe ReactorSDK::Resources::LibraryComparison do
  def build_resource(id:, type:, name:, revision_id:)
    raw_resource = {
      'id' => id,
      'type' => type,
      'attributes' => {
        'name' => name,
        'settings' => '{}'
      },
      'relationships' => {
        'latest_revision' => {
          'data' => { 'id' => revision_id, 'type' => 'revisions' }
        }
      }
    }

    resource_class = case type
                     when 'rules' then ReactorSDK::Resources::Rule
                     when 'data_elements' then ReactorSDK::Resources::DataElement
                     else ReactorSDK::Resources::Extension
                     end

    resource = resource_class.new(
      id: raw_resource.fetch('id'),
      type: raw_resource.fetch('type'),
      attributes: raw_resource.fetch('attributes'),
      relationships: raw_resource.fetch('relationships')
    )
    resource.instance_variable_set(:@revision_id, revision_id)
    resource.singleton_class.attr_reader :revision_id
    resource
  end

  subject(:comparison) do
    described_class.new(
      current_library_id: 'LB_DEV',
      baseline_library_id: 'LB_STG',
      property_id: 'PR123',
      current_snapshot: current_snapshot,
      baseline_snapshot: baseline_snapshot,
      entries: [modified_entry, added_entry, removed_entry, unchanged_entry]
    )
  end

  let(:current_rule) { build_resource(id: 'RL100', type: 'rules', name: 'Checkout Rule', revision_id: 'RE_CUR_RULE') }
  let(:baseline_rule) { build_resource(id: 'RL100', type: 'rules', name: 'Checkout Rule', revision_id: 'RE_BASE_RULE') }
  let(:current_extension) { build_resource(id: 'EX100', type: 'extensions', name: 'Core', revision_id: 'RE_EX') }
  let(:baseline_extension) { build_resource(id: 'EX100', type: 'extensions', name: 'Core', revision_id: 'RE_EX') }
  let(:added_rule) { build_resource(id: 'RL200', type: 'rules', name: 'Added Rule', revision_id: 'RE_ADDED') }
  let(:removed_data_element) { build_resource(id: 'DE200', type: 'data_elements', name: 'Removed Element', revision_id: 'RE_REMOVED') }

  let(:modified_entry) do
    ReactorSDK::Resources::LibraryComparisonEntry.new(
      resource_id: 'RL100',
      resource_type: 'rules',
      current_library_id: 'LB_DEV',
      baseline_library_id: 'LB_STG',
      current_resource: current_rule,
      baseline_resource: baseline_rule,
      current_revision_id: 'RE_CUR_RULE',
      baseline_revision_id: 'RE_BASE_RULE',
      current_comprehensive_resource: ReactorSDK::Resources::ComprehensiveRule.new(resource: current_rule, rule_components: []),
      baseline_comprehensive_resource: ReactorSDK::Resources::ComprehensiveRule.new(resource: baseline_rule, rule_components: [])
    )
  end

  let(:added_entry) do
    ReactorSDK::Resources::LibraryComparisonEntry.new(
      resource_id: 'RL200',
      resource_type: 'rules',
      current_library_id: 'LB_DEV',
      baseline_library_id: 'LB_STG',
      current_resource: added_rule,
      baseline_resource: nil,
      current_revision_id: 'RE_ADDED',
      baseline_revision_id: nil,
      current_comprehensive_resource: ReactorSDK::Resources::ComprehensiveRule.new(resource: added_rule, rule_components: []),
      baseline_comprehensive_resource: nil
    )
  end

  let(:removed_entry) do
    ReactorSDK::Resources::LibraryComparisonEntry.new(
      resource_id: 'DE200',
      resource_type: 'data_elements',
      current_library_id: 'LB_DEV',
      baseline_library_id: 'LB_STG',
      current_resource: nil,
      baseline_resource: removed_data_element,
      current_revision_id: nil,
      baseline_revision_id: 'RE_REMOVED',
      current_comprehensive_resource: nil,
      baseline_comprehensive_resource: ReactorSDK::Resources::ComprehensiveDataElement.new(
        resource: removed_data_element,
        referenced_data_elements: [],
        impacted_rules: []
      )
    )
  end

  let(:unchanged_entry) do
    ReactorSDK::Resources::LibraryComparisonEntry.new(
      resource_id: 'EX100',
      resource_type: 'extensions',
      current_library_id: 'LB_DEV',
      baseline_library_id: 'LB_STG',
      current_resource: current_extension,
      baseline_resource: baseline_extension,
      current_revision_id: 'RE_EX',
      baseline_revision_id: 'RE_EX',
      current_comprehensive_resource: ReactorSDK::Resources::ComprehensiveExtension.new(
        resource: current_extension,
        data_elements: [],
        rule_components: [],
        rules: []
      ),
      baseline_comprehensive_resource: ReactorSDK::Resources::ComprehensiveExtension.new(
        resource: baseline_extension,
        data_elements: [],
        rule_components: [],
        rules: []
      )
    )
  end

  let(:current_snapshot) { instance_double(ReactorSDK::Resources::LibrarySnapshot, library: instance_double(ReactorSDK::Resources::LibraryWithResources, id: 'LB_DEV')) }
  let(:baseline_snapshot) { instance_double(ReactorSDK::Resources::LibrarySnapshot, library: instance_double(ReactorSDK::Resources::LibraryWithResources, id: 'LB_STG')) }

  describe ReactorSDK::Resources::LibraryComparisonEntry do
    it 'classifies added, removed, modified, and unchanged resources' do
      expect(modified_entry.status).to eq('modified')
      expect(added_entry.status).to eq('added')
      expect(removed_entry.status).to eq('removed')
      expect(unchanged_entry.status).to eq('unchanged')
    end

    it 'builds Changeset-ready documents' do
      expect(modified_entry.changeset_document).to include(
        path: 'reactor/rules/RL100.json',
        language: 'json'
      )
      expect(modified_entry.changeset_document[:metadata]).to include(
        resource_id: 'RL100',
        status: 'modified',
        current_revision_id: 'RE_CUR_RULE',
        baseline_revision_id: 'RE_BASE_RULE'
      )
    end
  end

  describe '#changeset_documents' do
    it 'excludes unchanged entries by default' do
      expect(comparison.changeset_documents.map { |document| document[:path] }).to eq(
        %w[
          reactor/rules/RL100.json
          reactor/rules/RL200.json
          reactor/data_elements/DE200.json
        ]
      )
    end

    it 'can include unchanged entries when requested' do
      expect(comparison.changeset_documents(include_unchanged: true).map { |document| document[:path] }).to eq(
        %w[
          reactor/rules/RL100.json
          reactor/rules/RL200.json
          reactor/data_elements/DE200.json
          reactor/extensions/EX100.json
        ]
      )
    end
  end
end
