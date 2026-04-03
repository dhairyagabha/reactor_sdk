# frozen_string_literal: true

##
# @file spec/reactor_sdk/resources/rule_component_spec.rb
# @description Tests for ReactorSDK::Resources::RuleComponent.
#
#   Covers: attribute mapping, parsed_settings across all known
#   input types — JSON string, plain Hash, nil, blank, unparseable,
#   Core custom code, Web SDK XDM, Analytics variable mappings,
#   and large code blocks.
#

RSpec.describe ReactorSDK::Resources::RuleComponent do
  ##
  # Builds a RuleComponent with the given attributes.
  #
  def build_component(attributes = {})
    described_class.new(
      id: 'RC123',
      type: 'rule_components',
      attributes: attributes
    )
  end

  # ── Attribute mapping ─────────────────────────────────────────

  describe 'attribute mapping' do
    subject(:component) do
      build_component(
        'name' => 'Send Beacon',
        'delegate_descriptor_id' => 'adobe-analytics::actions::set-variables',
        'settings' => '{}',
        'order' => 1,
        'rule_order' => 50.0,
        'created_at' => '2024-01-01T00:00:00.000Z',
        'updated_at' => '2024-01-02T00:00:00.000Z'
      )
    end

    it { expect(component.name).to eq('Send Beacon') }
    it { expect(component.delegate_descriptor_id).to eq('adobe-analytics::actions::set-variables') }
    it { expect(component.order).to eq(1) }
    it { expect(component.rule_order).to eq(50.0) }
    it { expect(component.created_at).to eq('2024-01-01T00:00:00.000Z') }
    it { expect(component.updated_at).to eq('2024-01-02T00:00:00.000Z') }
  end

  # ── parsed_settings ───────────────────────────────────────────

  describe '#parsed_settings' do
    context 'with Core custom code — JavaScript' do
      it 'parses the JSON-encoded string into a Hash' do
        component = build_component(
          'settings' => "{\"source\":\"var x = _satellite.getVar('page_name');\",\"language\":\"javascript\"}"
        )
        expect(component.parsed_settings).to eq(
          'source' => "var x = _satellite.getVar('page_name');",
          'language' => 'javascript'
        )
      end
    end

    context 'with Core custom code — HTML' do
      it 'parses the JSON-encoded string and preserves HTML content exactly' do
        html = "<div class='modal'><h1>Hello</h1></div>"
        component = build_component(
          'settings' => "{\"source\":\"#{html}\",\"language\":\"html\"}"
        )
        expect(component.parsed_settings['source']).to eq(html)
        expect(component.parsed_settings['language']).to eq('html')
      end
    end

    context 'with Adobe Web SDK — XDM object' do
      it 'parses the XDM structure into a nested Hash' do
        xdm_settings = {
          'xdm' => {
            'eventType' => 'web.webpagedetails.pageViews',
            'web' => {
              'webPageDetails' => {
                'name' => '%page_name%',
                'URL' => '%page_url%'
              }
            }
          },
          'data' => {
            '__adobe' => {
              'analytics' => { 'eVar1' => '%order_id%' }
            }
          }
        }
        component = build_component('settings' => JSON.generate(xdm_settings))
        expect(component.parsed_settings['xdm']['eventType']).to eq('web.webpagedetails.pageViews')
        expect(component.parsed_settings['data']['__adobe']['analytics']['eVar1']).to eq('%order_id%')
      end
    end

    context 'with Adobe Analytics — variable mappings' do
      it 'parses the variable mapping structure correctly' do
        analytics_settings = {
          'trackerProperties' => {
            'eVars' => [{ 'type' => 'value', 'value' => '%product%', 'name' => 'eVar1' }],
            'events' => [{ 'name' => 'event1' }]
          },
          'customSetup' => {
            'source' => "s.linkTrackVars='None';"
          }
        }
        component = build_component('settings' => JSON.generate(analytics_settings))
        expect(component.parsed_settings['trackerProperties']['eVars'].first['name']).to eq('eVar1')
        expect(component.parsed_settings['customSetup']['source']).to eq("s.linkTrackVars='None';")
      end
    end

    context 'when settings is already a Hash' do
      it 'returns it as-is without re-parsing' do
        hash = { 'trackerVariableName' => 's' }
        component = build_component('settings' => hash)
        expect(component.parsed_settings).to eq(hash)
      end
    end

    context 'when settings is nil' do
      it 'returns an empty Hash' do
        component = build_component('settings' => nil)
        expect(component.parsed_settings).to eq({})
      end
    end

    context 'when settings is a blank string' do
      it 'returns an empty Hash' do
        component = build_component('settings' => '')
        expect(component.parsed_settings).to eq({})
      end
    end

    context 'when settings is unparseable JSON' do
      it 'returns an empty Hash without raising' do
        component = build_component('settings' => '{invalid json{{{')
        expect { component.parsed_settings }.not_to raise_error
        expect(component.parsed_settings).to eq({})
      end

      it 'preserves the raw value on the settings attribute' do
        component = build_component('settings' => '{invalid json{{{')
        component.parsed_settings
        expect(component.settings).to eq('{invalid json{{{')
      end
    end

    context 'when settings is an empty JSON object' do
      it 'returns an empty Hash' do
        component = build_component('settings' => '{}')
        expect(component.parsed_settings).to eq({})
      end
    end

    context 'with a large custom code block' do
      it 'parses without truncation' do
        large_code = "var x = 1;\n" * 500
        component  = build_component(
          'settings' => JSON.generate({ 'source' => large_code, 'language' => 'javascript' })
        )
        expect(component.parsed_settings['source'].length).to eq(large_code.length)
        expect(component.parsed_settings['source']).to eq(large_code)
      end
    end

    context 'when raw settings are never modified' do
      it 'preserves the original JSON string after calling parsed_settings' do
        raw = '{"source":"var x = 1;"}'
        component = build_component('settings' => raw)
        component.parsed_settings
        expect(component.settings).to eq(raw)
      end
    end
  end

  # ── inspect ───────────────────────────────────────────────────

  describe '#inspect' do
    it 'includes id, name and delegate_descriptor_id' do
      component = build_component(
        'name' => 'Custom Code',
        'delegate_descriptor_id' => 'core::actions::custom-code'
      )
      expect(component.inspect).to include('RC123')
      expect(component.inspect).to include('Custom Code')
      expect(component.inspect).to include('core::actions::custom-code')
    end
  end
end
