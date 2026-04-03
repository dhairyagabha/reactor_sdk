# frozen_string_literal: true

RSpec.describe ReactorSDK::ResourceNormalizer do
  describe '.normalize_resource' do
    it 'normalizes core custom code data elements' do
      resource = ReactorSDK::Resources::DataElement.new(
        id: 'DE123',
        type: 'data_elements',
        attributes: {
          'name' => 'Page Name',
          'delegate_descriptor_id' => 'core::dataElements::custom-code',
          'settings' => JSON.generate({ 'source' => 'return document.title;' })
        }
      )

      payload = described_class.normalize_resource(resource)

      expect(payload['kind']).to eq('data_element')
      expect(payload['configuration']).to eq(
        'language' => 'javascript',
        'source' => 'return document.title;'
      )
      expect(payload['normalization_status']).to eq('normalized')
    end

    it 'normalizes core custom code rule components' do
      resource = ReactorSDK::Resources::RuleComponent.new(
        id: 'RC123',
        type: 'rule_components',
        attributes: {
          'name' => 'Custom Code',
          'delegate_descriptor_id' => 'core::actions::custom-code',
          'settings' => JSON.generate({ 'source' => 'console.log("hi");', 'language' => 'javascript' })
        }
      )

      payload = described_class.normalize_resource(resource)

      expect(payload['kind']).to eq('rule_component')
      expect(payload['configuration']).to eq(
        'language' => 'javascript',
        'source' => 'console.log("hi");'
      )
      expect(payload['normalization_status']).to eq('normalized')
    end

    it 'normalizes Adobe Web SDK payloads' do
      resource = ReactorSDK::Resources::RuleComponent.new(
        id: 'RC456',
        type: 'rule_components',
        attributes: {
          'name' => 'Send Event',
          'delegate_descriptor_id' => 'adobe-alloy::actions::send-event',
          'settings' => JSON.generate({ 'xdm' => { 'eventType' => 'web.webpagedetails.pageViews' } })
        }
      )

      payload = described_class.normalize_resource(resource)

      expect(payload['configuration']).to eq(
        'xdm' => { 'eventType' => 'web.webpagedetails.pageViews' }
      )
      expect(payload['normalization_status']).to eq('normalized')
    end

    it 'normalizes Adobe Analytics payloads' do
      resource = ReactorSDK::Resources::RuleComponent.new(
        id: 'RC789',
        type: 'rule_components',
        attributes: {
          'name' => 'Set Variables',
          'delegate_descriptor_id' => 'adobe-analytics::actions::set-variables',
          'settings' => JSON.generate({ 'trackerProperties' => { 'eVars' => [{ 'name' => 'eVar1' }] } })
        }
      )

      payload = described_class.normalize_resource(resource)

      expect(payload['configuration']).to eq(
        'trackerProperties' => { 'eVars' => [{ 'name' => 'eVar1' }] }
      )
      expect(payload['normalization_status']).to eq('normalized')
    end

    it 'falls back to parsed JSON for unknown delegates' do
      resource = ReactorSDK::Resources::Extension.new(
        id: 'EX123',
        type: 'extensions',
        attributes: {
          'name' => 'Unknown Extension',
          'delegate_descriptor_id' => 'vendor-x::extension',
          'settings' => JSON.generate({ 'foo' => 'bar' })
        }
      )

      payload = described_class.normalize_resource(resource)

      expect(payload['configuration']).to eq('foo' => 'bar')
      expect(payload['normalization_status']).to eq('parsed')
    end

    it 'falls back to raw Launch output when parsing fails' do
      resource = ReactorSDK::Resources::Extension.new(
        id: 'EX456',
        type: 'extensions',
        attributes: {
          'name' => 'Broken Extension',
          'delegate_descriptor_id' => 'vendor-x::extension',
          'settings' => '{invalid json'
        }
      )

      payload = described_class.normalize_resource(resource)

      expect(payload['configuration']).to eq('{invalid json')
      expect(payload['normalization_status']).to eq('raw')
      expect(payload['launch_raw']).to include(
        attributes: include('settings' => '{invalid json')
      )
    end
  end
end
