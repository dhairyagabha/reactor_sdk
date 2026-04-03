# frozen_string_literal: true

##
# @file spec/reactor_sdk/endpoints/libraries_spec.rb
# @description Tests for ReactorSDK::Endpoints::Libraries.
#
#   Covers: list, find, create, add/remove/set for rules/data_elements/
#   extensions, assign_environment, transition, build,
#   find_with_resources, upstream_libraries, and error handling.
#

RSpec.describe ReactorSDK::Endpoints::Libraries do
  subject(:client) { test_client }

  let(:library_attributes) do
    {
      'name' => 'Release 1.0',
      'state' => 'development',
      'published' => false,
      'created_at' => '2024-01-01T00:00:00.000Z',
      'updated_at' => '2024-01-01T00:00:00.000Z',
      'published_at' => nil
    }
  end

  let(:build_attributes) do
    {
      'status' => 'succeeded',
      'created_at' => '2024-01-01T00:00:00.000Z',
      'updated_at' => '2024-01-01T00:00:00.000Z'
    }
  end

  let(:single_response) do
    jsonapi_response(
      type: 'libraries',
      id: 'LB123',
      attributes: library_attributes
    ).to_json
  end

  let(:list_response) do
    jsonapi_list_response(
      type: 'libraries',
      items: [
        { id: 'LB123', attributes: library_attributes },
        { id: 'LB456', attributes: library_attributes.merge('name' => 'Release 2.0') }
      ]
    ).to_json
  end

  let(:build_response) do
    jsonapi_response(
      type: 'builds',
      id: 'BL123',
      attributes: build_attributes
    ).to_json
  end

  # ── list_for_property ─────────────────────────────────────────

  describe '#list_for_property' do
    before do
      stub_request(:get, 'https://reactor.adobe.io/properties/PR123/libraries?page%5Bsize%5D=100')
        .to_return(status: 200, body: list_response, headers: { 'Content-Type' => 'application/json' })
    end

    it 'returns an array of Library resources' do
      result = client.libraries.list_for_property('PR123')
      expect(result).to all(be_a(ReactorSDK::Resources::Library))
    end

    it 'returns the correct number of libraries' do
      result = client.libraries.list_for_property('PR123')
      expect(result.length).to eq(2)
    end

    it 'maps attributes to Ruby methods' do
      result = client.libraries.list_for_property('PR123')
      expect(result.first.name).to eq('Release 1.0')
      expect(result.first.state).to eq('development')
    end

    it 'returns the correct ids' do
      result = client.libraries.list_for_property('PR123')
      expect(result.map(&:id)).to eq(%w[LB123 LB456])
    end
  end

  # ── find ──────────────────────────────────────────────────────

  describe '#find' do
    before do
      stub_request(:get, 'https://reactor.adobe.io/libraries/LB123')
        .to_return(status: 200, body: single_response, headers: { 'Content-Type' => 'application/json' })
    end

    it 'returns a Library resource' do
      result = client.libraries.find('LB123')
      expect(result).to be_a(ReactorSDK::Resources::Library)
    end

    it 'maps the id correctly' do
      result = client.libraries.find('LB123')
      expect(result.id).to eq('LB123')
    end

    it 'maps attributes to Ruby methods' do
      result = client.libraries.find('LB123')
      expect(result.name).to eq('Release 1.0')
      expect(result.state).to eq('development')
      expect(result.buildable?).to be(true)
      expect(result.published?).to be(false)
    end

    context 'when the library does not exist' do
      before do
        stub_request(:get, 'https://reactor.adobe.io/libraries/LB_INVALID')
          .to_return(status: 404, body: { errors: [] }.to_json)
      end

      it 'raises ResourceNotFoundError' do
        expect do
          client.libraries.find('LB_INVALID')
        end.to raise_error(ReactorSDK::ResourceNotFoundError)
      end
    end
  end

  # ── create ────────────────────────────────────────────────────

  describe '#create' do
    before do
      stub_request(:post, 'https://reactor.adobe.io/properties/PR123/libraries')
        .to_return(status: 201, body: single_response, headers: { 'Content-Type' => 'application/json' })
    end

    it 'returns a Library resource' do
      result = client.libraries.create(property_id: 'PR123', name: 'Release 1.0')
      expect(result).to be_a(ReactorSDK::Resources::Library)
    end

    it 'maps attributes on the returned resource' do
      result = client.libraries.create(property_id: 'PR123', name: 'Release 1.0')
      expect(result.name).to eq('Release 1.0')
      expect(result.state).to eq('development')
    end
  end

  # ── Rules relationship management ─────────────────────────────

  describe '#add_rules' do
    before do
      stub_request(:post, 'https://reactor.adobe.io/libraries/LB123/relationships/rules')
        .to_return(status: 201, body: '')
    end

    it 'returns nil on success' do
      expect(client.libraries.add_rules('LB123', %w[RL123 RL456])).to be_nil
    end

    it 'sends the correct relationship payload' do
      client.libraries.add_rules('LB123', %w[RL123 RL456])
      expect(WebMock).to have_requested(:post, 'https://reactor.adobe.io/libraries/LB123/relationships/rules')
        .with(body: { data: [{ id: 'RL123', type: 'rules' }, { id: 'RL456', type: 'rules' }] }.to_json)
    end
  end

  describe '#remove_rules' do
    before do
      stub_request(:delete, 'https://reactor.adobe.io/libraries/LB123/relationships/rules')
        .to_return(status: 204, body: '')
    end

    it 'returns nil on success' do
      expect(client.libraries.remove_rules('LB123', ['RL123'])).to be_nil
    end

    it 'sends the correct relationship payload' do
      client.libraries.remove_rules('LB123', ['RL123'])
      expect(WebMock).to have_requested(:delete, 'https://reactor.adobe.io/libraries/LB123/relationships/rules')
        .with(body: { data: [{ id: 'RL123', type: 'rules' }] }.to_json)
    end

    it 'supports removing multiple rules at once' do
      client.libraries.remove_rules('LB123', %w[RL123 RL456])
      expect(WebMock).to have_requested(:delete, 'https://reactor.adobe.io/libraries/LB123/relationships/rules')
        .with(body: { data: [{ id: 'RL123', type: 'rules' }, { id: 'RL456', type: 'rules' }] }.to_json)
    end
  end

  describe '#set_rules' do
    before do
      stub_request(:patch, 'https://reactor.adobe.io/libraries/LB123/relationships/rules')
        .to_return(status: 204, body: '')
    end

    it 'returns nil on success' do
      expect(client.libraries.set_rules('LB123', ['RL456'])).to be_nil
    end

    it 'sends the complete replacement payload' do
      client.libraries.set_rules('LB123', ['RL456'])
      expect(WebMock).to have_requested(:patch, 'https://reactor.adobe.io/libraries/LB123/relationships/rules')
        .with(body: { data: [{ id: 'RL456', type: 'rules' }] }.to_json)
    end

    it 'supports setting an empty list to remove all rules' do
      client.libraries.set_rules('LB123', [])
      expect(WebMock).to have_requested(:patch, 'https://reactor.adobe.io/libraries/LB123/relationships/rules')
        .with(body: { data: [] }.to_json)
    end
  end

  # ── Data elements relationship management ─────────────────────

  describe '#add_data_elements' do
    before do
      stub_request(:post, 'https://reactor.adobe.io/libraries/LB123/relationships/data_elements')
        .to_return(status: 201, body: '')
    end

    it 'returns nil on success' do
      expect(client.libraries.add_data_elements('LB123', ['DE123'])).to be_nil
    end

    it 'sends the correct relationship payload' do
      client.libraries.add_data_elements('LB123', ['DE123'])
      expect(WebMock).to have_requested(:post, 'https://reactor.adobe.io/libraries/LB123/relationships/data_elements')
        .with(body: { data: [{ id: 'DE123', type: 'data_elements' }] }.to_json)
    end
  end

  describe '#remove_data_elements' do
    before do
      stub_request(:delete, 'https://reactor.adobe.io/libraries/LB123/relationships/data_elements')
        .to_return(status: 204, body: '')
    end

    it 'returns nil on success' do
      expect(client.libraries.remove_data_elements('LB123', ['DE123'])).to be_nil
    end

    it 'sends the correct relationship payload' do
      client.libraries.remove_data_elements('LB123', ['DE123'])
      expect(WebMock).to have_requested(:delete, 'https://reactor.adobe.io/libraries/LB123/relationships/data_elements')
        .with(body: { data: [{ id: 'DE123', type: 'data_elements' }] }.to_json)
    end

    it 'supports removing multiple data elements at once' do
      client.libraries.remove_data_elements('LB123', %w[DE123 DE456])
      expect(WebMock).to have_requested(:delete, 'https://reactor.adobe.io/libraries/LB123/relationships/data_elements')
        .with(body: { data: [{ id: 'DE123', type: 'data_elements' }, { id: 'DE456', type: 'data_elements' }] }.to_json)
    end
  end

  describe '#set_data_elements' do
    before do
      stub_request(:patch, 'https://reactor.adobe.io/libraries/LB123/relationships/data_elements')
        .to_return(status: 204, body: '')
    end

    it 'returns nil on success' do
      expect(client.libraries.set_data_elements('LB123', ['DE456'])).to be_nil
    end

    it 'sends the complete replacement payload' do
      client.libraries.set_data_elements('LB123', ['DE456'])
      expect(WebMock).to have_requested(:patch, 'https://reactor.adobe.io/libraries/LB123/relationships/data_elements')
        .with(body: { data: [{ id: 'DE456', type: 'data_elements' }] }.to_json)
    end

    it 'supports setting an empty list to remove all data elements' do
      client.libraries.set_data_elements('LB123', [])
      expect(WebMock).to have_requested(:patch, 'https://reactor.adobe.io/libraries/LB123/relationships/data_elements')
        .with(body: { data: [] }.to_json)
    end
  end

  # ── Extensions relationship management ────────────────────────

  describe '#add_extensions' do
    before do
      stub_request(:post, 'https://reactor.adobe.io/libraries/LB123/relationships/extensions')
        .to_return(status: 201, body: '')
    end

    it 'returns nil on success' do
      expect(client.libraries.add_extensions('LB123', ['EX123'])).to be_nil
    end

    it 'sends the correct relationship payload' do
      client.libraries.add_extensions('LB123', ['EX123'])
      expect(WebMock).to have_requested(:post, 'https://reactor.adobe.io/libraries/LB123/relationships/extensions')
        .with(body: { data: [{ id: 'EX123', type: 'extensions' }] }.to_json)
    end
  end

  describe '#remove_extensions' do
    before do
      stub_request(:delete, 'https://reactor.adobe.io/libraries/LB123/relationships/extensions')
        .to_return(status: 204, body: '')
    end

    it 'returns nil on success' do
      expect(client.libraries.remove_extensions('LB123', ['EX123'])).to be_nil
    end

    it 'sends the correct relationship payload' do
      client.libraries.remove_extensions('LB123', ['EX123'])
      expect(WebMock).to have_requested(:delete, 'https://reactor.adobe.io/libraries/LB123/relationships/extensions')
        .with(body: { data: [{ id: 'EX123', type: 'extensions' }] }.to_json)
    end

    it 'supports removing multiple extensions at once' do
      client.libraries.remove_extensions('LB123', %w[EX123 EX456])
      expect(WebMock).to have_requested(:delete, 'https://reactor.adobe.io/libraries/LB123/relationships/extensions')
        .with(body: { data: [{ id: 'EX123', type: 'extensions' }, { id: 'EX456', type: 'extensions' }] }.to_json)
    end
  end

  describe '#set_extensions' do
    before do
      stub_request(:patch, 'https://reactor.adobe.io/libraries/LB123/relationships/extensions')
        .to_return(status: 204, body: '')
    end

    it 'returns nil on success' do
      expect(client.libraries.set_extensions('LB123', ['EX456'])).to be_nil
    end

    it 'sends the complete replacement payload' do
      client.libraries.set_extensions('LB123', ['EX456'])
      expect(WebMock).to have_requested(:patch, 'https://reactor.adobe.io/libraries/LB123/relationships/extensions')
        .with(body: { data: [{ id: 'EX456', type: 'extensions' }] }.to_json)
    end

    it 'supports setting an empty list to remove all extensions' do
      client.libraries.set_extensions('LB123', [])
      expect(WebMock).to have_requested(:patch, 'https://reactor.adobe.io/libraries/LB123/relationships/extensions')
        .with(body: { data: [] }.to_json)
    end
  end

  # ── assign_environment ────────────────────────────────────────

  describe '#assign_environment' do
    before do
      stub_request(:patch, 'https://reactor.adobe.io/libraries/LB123/relationships/environment')
        .to_return(status: 204, body: '')
    end

    it 'returns nil on success' do
      expect(client.libraries.assign_environment('LB123', 'EN123')).to be_nil
    end

    it 'sends the correct relationship payload' do
      client.libraries.assign_environment('LB123', 'EN123')
      expect(WebMock).to have_requested(:patch, 'https://reactor.adobe.io/libraries/LB123/relationships/environment')
        .with(body: { data: { id: 'EN123', type: 'environments' } }.to_json)
    end
  end

  # ── transition ────────────────────────────────────────────────

  describe '#transition' do
    before do
      stub_request(:patch, 'https://reactor.adobe.io/libraries/LB123')
        .to_return(
          status: 200,
          body: jsonapi_response(
            type: 'libraries',
            id: 'LB123',
            attributes: library_attributes.merge('state' => 'submitted')
          ).to_json,
          headers: { 'Content-Type' => 'application/json' }
        )
    end

    it 'returns a Library resource' do
      result = client.libraries.transition('LB123', state: 'submitted')
      expect(result).to be_a(ReactorSDK::Resources::Library)
    end

    it 'reflects the new state' do
      result = client.libraries.transition('LB123', state: 'submitted')
      expect(result.state).to eq('submitted')
    end

    it 'sends the transition as a meta action' do
      client.libraries.transition('LB123', state: 'submitted')
      expect(WebMock).to have_requested(:patch, 'https://reactor.adobe.io/libraries/LB123')
        .with(
          body: {
            data: {
              id: 'LB123',
              type: 'libraries',
              meta: { action: 'submit' }
            }
          }.to_json
        )
    end
  end

  # ── build ─────────────────────────────────────────────────────

  describe '#build' do
    before do
      stub_request(:post, 'https://reactor.adobe.io/libraries/LB123/builds')
        .to_return(status: 201, body: build_response, headers: { 'Content-Type' => 'application/json' })
    end

    it 'returns a Build resource' do
      result = client.libraries.build('LB123')
      expect(result).to be_a(ReactorSDK::Resources::Build)
    end

    it 'maps build attributes correctly' do
      result = client.libraries.build('LB123')
      expect(result.status).to eq('succeeded')
      expect(result.succeeded?).to be(true)
    end
  end

  describe 'additional library operations' do
    it 'updates and deletes a library' do
      stub_request(:patch, 'https://reactor.adobe.io/libraries/LB123')
        .to_return(status: 200, body: single_response, headers: { 'Content-Type' => 'application/json' })
      stub_request(:delete, 'https://reactor.adobe.io/libraries/LB123')
        .to_return(status: 204, body: '')

      expect(client.libraries.update('LB123', name: 'Release 1.0')).to be_a(ReactorSDK::Resources::Library)
      expect(client.libraries.delete('LB123')).to be_nil
    end

    it 'fetches related resources and relationship linkages' do
      stub_request(:get, 'https://reactor.adobe.io/libraries/LB123/property')
        .to_return(
          status: 200,
          body: jsonapi_response(
            type: 'properties',
            id: 'PR123',
            attributes: { 'name' => 'Property', 'platform' => 'web' }
          ).to_json,
          headers: { 'Content-Type' => 'application/json' }
        )
      stub_request(:get, 'https://reactor.adobe.io/libraries/LB123/environment')
        .to_return(
          status: 200,
          body: jsonapi_response(
            type: 'environments',
            id: 'EN123',
            attributes: { 'name' => 'Dev', 'stage' => 'development' }
          ).to_json,
          headers: { 'Content-Type' => 'application/json' }
        )
      stub_request(:get, 'https://reactor.adobe.io/libraries/LB123/upstream_library')
        .to_return(status: 200, body: single_response, headers: { 'Content-Type' => 'application/json' })
      stub_request(:get, 'https://reactor.adobe.io/libraries/LB123/rules?page%5Bsize%5D=100')
        .to_return(
          status: 200,
          body: jsonapi_list_response(
            type: 'rules',
            items: [{ id: 'RL123', attributes: { 'name' => 'Rule', 'enabled' => true } }]
          ).to_json,
          headers: { 'Content-Type' => 'application/json' }
        )
      stub_request(:get, 'https://reactor.adobe.io/libraries/LB123/data_elements?page%5Bsize%5D=100')
        .to_return(
          status: 200,
          body: jsonapi_list_response(
            type: 'data_elements',
            items: [{ id: 'DE123', attributes: { 'name' => 'DE' } }]
          ).to_json,
          headers: { 'Content-Type' => 'application/json' }
        )
      stub_request(:get, 'https://reactor.adobe.io/libraries/LB123/extensions?page%5Bsize%5D=100')
        .to_return(
          status: 200,
          body: jsonapi_list_response(
            type: 'extensions',
            items: [{ id: 'EX123', attributes: { 'name' => 'Core' } }]
          ).to_json,
          headers: { 'Content-Type' => 'application/json' }
        )
      stub_request(:get, 'https://reactor.adobe.io/libraries/LB123/relationships/rules')
        .to_return(status: 200, body: { data: [{ id: 'RL123', type: 'rules' }] }.to_json)
      stub_request(:get, 'https://reactor.adobe.io/libraries/LB123/relationships/data_elements')
        .to_return(status: 200, body: { data: [{ id: 'DE123', type: 'data_elements' }] }.to_json)
      stub_request(:get, 'https://reactor.adobe.io/libraries/LB123/relationships/extensions')
        .to_return(status: 200, body: { data: [{ id: 'EX123', type: 'extensions' }] }.to_json)
      stub_request(:get, 'https://reactor.adobe.io/libraries/LB123/relationships/environment')
        .to_return(status: 200, body: { data: { id: 'EN123', type: 'environments' } }.to_json)
      stub_request(:delete, 'https://reactor.adobe.io/libraries/LB123/relationships/environment')
        .to_return(status: 204, body: '')
      stub_request(:get, 'https://reactor.adobe.io/libraries/LB123/notes?page%5Bsize%5D=100')
        .to_return(
          status: 200,
          body: jsonapi_list_response(
            type: 'notes',
            items: [{ id: 'NT123', attributes: { 'text' => 'Library note' } }]
          ).to_json,
          headers: { 'Content-Type' => 'application/json' }
        )
      stub_request(:post, 'https://reactor.adobe.io/libraries/LB123/notes')
        .to_return(
          status: 201,
          body: jsonapi_response(type: 'notes', id: 'NT123', attributes: { 'text' => 'Library note' }).to_json,
          headers: { 'Content-Type' => 'application/json' }
        )

      expect(client.libraries.property('LB123')).to be_a(ReactorSDK::Resources::Property)
      expect(client.libraries.environment('LB123')).to be_a(ReactorSDK::Resources::Environment)
      expect(client.libraries.upstream_library('LB123')).to be_a(ReactorSDK::Resources::Library)
      expect(client.libraries.rules('LB123')).to all(be_a(ReactorSDK::Resources::Rule))
      expect(client.libraries.data_elements('LB123')).to all(be_a(ReactorSDK::Resources::DataElement))
      expect(client.libraries.extensions('LB123')).to all(be_a(ReactorSDK::Resources::Extension))
      expect(client.libraries.rule_relationships('LB123')).to eq([{ 'id' => 'RL123', 'type' => 'rules' }])
      expect(client.libraries.data_element_relationships('LB123')).to eq([{ 'id' => 'DE123', 'type' => 'data_elements' }])
      expect(client.libraries.extension_relationships('LB123')).to eq([{ 'id' => 'EX123', 'type' => 'extensions' }])
      expect(client.libraries.environment_relationship('LB123')).to eq({ 'id' => 'EN123', 'type' => 'environments' })
      expect(client.libraries.remove_environment('LB123')).to be_nil
      expect(client.libraries.list_notes('LB123').first).to be_a(ReactorSDK::Resources::Note)
      expect(client.libraries.create_note('LB123', 'Library note')).to be_a(ReactorSDK::Resources::Note)
    end
  end

  # ── find_with_resources ───────────────────────────────────────

  describe '#find_with_resources' do
    let(:with_resources_response) do
      {
        'data' => {
          'id' => 'LB123',
          'type' => 'libraries',
          'attributes' => library_attributes
        },
        'included' => [
          {
            'id' => 'RL123', 'type' => 'rules',
            'attributes' => { 'name' => 'Order Confirmation', 'enabled' => true },
            'relationships' => { 'latest_revision' => { 'data' => { 'id' => 'RE001', 'type' => 'revisions' } } }
          },
          {
            'id' => 'RL456', 'type' => 'rules',
            'attributes' => { 'name' => 'Add to Cart', 'enabled' => true },
            'relationships' => { 'latest_revision' => { 'data' => { 'id' => 'RE002', 'type' => 'revisions' } } }
          },
          {
            'id' => 'DE123', 'type' => 'data_elements',
            'attributes' => { 'name' => 'Page Name' },
            'relationships' => { 'latest_revision' => { 'data' => { 'id' => 'RE010', 'type' => 'revisions' } } }
          },
          {
            'id' => 'EX123', 'type' => 'extensions',
            'attributes' => { 'name' => 'Adobe Analytics' },
            'relationships' => { 'latest_revision' => { 'data' => { 'id' => 'RE020', 'type' => 'revisions' } } }
          }
        ]
      }.to_json
    end

    before do
      stub_request(:get, 'https://reactor.adobe.io/libraries/LB123?include=rules%2Cdata_elements%2Cextensions')
        .to_return(status: 200, body: with_resources_response, headers: { 'Content-Type' => 'application/json' })
    end

    it 'returns a LibraryWithResources resource' do
      expect(client.libraries.find_with_resources('LB123')).to be_a(ReactorSDK::Resources::LibraryWithResources)
    end

    it 'maps library attributes correctly' do
      result = client.libraries.find_with_resources('LB123')
      expect(result.name).to eq('Release 1.0')
      expect(result.state).to eq('development')
    end

    it 'returns the correct number of rules' do
      expect(client.libraries.find_with_resources('LB123').rules.length).to eq(2)
    end

    it 'attaches revision_id to each rule' do
      result = client.libraries.find_with_resources('LB123')
      expect(result.rules.first.revision_id).to eq('RE001')
      expect(result.rules.last.revision_id).to eq('RE002')
    end

    it 'returns the correct number of data elements' do
      expect(client.libraries.find_with_resources('LB123').data_elements.length).to eq(1)
    end

    it 'attaches revision_id to each data element' do
      expect(client.libraries.find_with_resources('LB123').data_elements.first.revision_id).to eq('RE010')
    end

    it 'returns the correct number of extensions' do
      expect(client.libraries.find_with_resources('LB123').extensions.length).to eq(1)
    end

    it 'attaches revision_id to each extension' do
      expect(client.libraries.find_with_resources('LB123').extensions.first.revision_id).to eq('RE020')
    end

    it 'builds the resource_index correctly' do
      result = client.libraries.find_with_resources('LB123')
      expect(result.resource_index).to eq(
        'RL123' => 'RE001',
        'RL456' => 'RE002',
        'DE123' => 'RE010',
        'EX123' => 'RE020'
      )
    end
  end

  # ── upstream_libraries ────────────────────────────────────────

  describe '#upstream_libraries' do
    let(:dev_env_id)  { 'EN_DEV' }
    let(:stg_env_id)  { 'EN_STG' }
    let(:prod_env_id) { 'EN_PRD' }

    let(:dev_library) do
      { 'id' => 'LB_DEV', 'type' => 'libraries', 'attributes' => library_attributes.merge('name' => 'Dev Library') }
    end
    let(:stg_library) do
      { 'id' => 'LB_STG', 'type' => 'libraries', 'attributes' => library_attributes.merge('name' => 'Staging Library') }
    end
    let(:prod_library) do
      { 'id' => 'LB_PRD', 'type' => 'libraries',
        'attributes' => library_attributes.merge('name' => 'Production Library') }
    end

    def stub_library_find(library_id, attrs)
      stub_request(:get, "https://reactor.adobe.io/libraries/#{library_id}")
        .to_return(
          status: 200,
          body: { 'data' => { 'id' => library_id, 'type' => 'libraries', 'attributes' => attrs } }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )
    end

    def stub_library_env(library_id, env_id)
      stub_request(:get, "https://reactor.adobe.io/libraries/#{library_id}/relationships/environment")
        .to_return(
          status: 200,
          body: { 'data' => { 'id' => env_id, 'type' => 'environments' } }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )
    end

    def stub_env_stage(env_id, stage)
      stub_request(:get, "https://reactor.adobe.io/environments/#{env_id}")
        .to_return(
          status: 200,
          body: { 'data' => { 'id' => env_id, 'type' => 'environments',
                              'attributes' => { 'stage' => stage } } }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )
    end

    context 'when target is the Development library' do
      before do
        stub_library_find('LB_DEV', library_attributes.merge('name' => 'Dev Library'))
        stub_library_find('LB_STG', library_attributes.merge('name' => 'Staging Library'))
        stub_library_find('LB_PRD', library_attributes.merge('name' => 'Production Library'))
        stub_request(:get, 'https://reactor.adobe.io/properties/PR123/libraries?page%5Bsize%5D=100')
          .to_return(
            status: 200,
            body: { 'data' => [dev_library, stg_library, prod_library], 'links' => { 'next' => nil } }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
        stub_library_env('LB_DEV', dev_env_id)
        stub_library_env('LB_STG', stg_env_id)
        stub_library_env('LB_PRD', prod_env_id)
        stub_env_stage(dev_env_id,  'development')
        stub_env_stage(stg_env_id,  'staging')
        stub_env_stage(prod_env_id, 'production')
      end

      it 'returns staging and production libraries' do
        expect(client.libraries.upstream_libraries('LB_DEV', property_id: 'PR123').length).to eq(2)
      end

      it 'returns staging library first' do
        result = client.libraries.upstream_libraries('LB_DEV', property_id: 'PR123')
        expect(result.first.name).to eq('Staging Library')
      end

      it 'returns production library last' do
        result = client.libraries.upstream_libraries('LB_DEV', property_id: 'PR123')
        expect(result.last.name).to eq('Production Library')
      end

      it 'returns Library resources' do
        result = client.libraries.upstream_libraries('LB_DEV', property_id: 'PR123')
        expect(result).to all(be_a(ReactorSDK::Resources::Library))
      end
    end

    context 'when target is the Staging library' do
      before do
        stub_library_find('LB_STG', library_attributes.merge('name' => 'Staging Library'))
        stub_library_find('LB_PRD', library_attributes.merge('name' => 'Production Library'))
        stub_request(:get, 'https://reactor.adobe.io/properties/PR123/libraries?page%5Bsize%5D=100')
          .to_return(
            status: 200,
            body: { 'data' => [stg_library, prod_library], 'links' => { 'next' => nil } }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
        stub_library_env('LB_STG', stg_env_id)
        stub_library_env('LB_PRD', prod_env_id)
        stub_env_stage(stg_env_id,  'staging')
        stub_env_stage(prod_env_id, 'production')
      end

      it 'returns only the production library' do
        result = client.libraries.upstream_libraries('LB_STG', property_id: 'PR123')
        expect(result.length).to eq(1)
        expect(result.first.name).to eq('Production Library')
      end
    end

    context 'when target is the Production library' do
      before do
        stub_library_find('LB_PRD', library_attributes.merge('name' => 'Production Library'))
        stub_library_env('LB_PRD', prod_env_id)
        stub_env_stage(prod_env_id, 'production')
      end

      it 'returns an empty array' do
        expect(client.libraries.upstream_libraries('LB_PRD', property_id: 'PR123')).to eq([])
      end
    end
  end

  # ── upstream_chain_for_resource ──────────────────────────────

  describe '#upstream_chain_for_resource' do
    def library_payload(library_id, name)
      {
        'id' => library_id,
        'type' => 'libraries',
        'attributes' => library_attributes.merge('name' => name)
      }
    end

    def target_with_resources
      {
        'data' => library_payload('LB_DEV', 'Dev Library'),
        'included' => [
          {
            'id' => 'RL123',
            'type' => 'rules',
            'attributes' => { 'name' => 'Order Confirmation', 'enabled' => true },
            'relationships' => { 'latest_revision' => { 'data' => { 'id' => 'RE_DEV', 'type' => 'revisions' } } }
          }
        ]
      }.to_json
    end

    def staging_with_resources
      {
        'data' => library_payload('LB_STG', 'Staging Library'),
        'included' => [
          {
            'id' => 'RL123',
            'type' => 'rules',
            'attributes' => { 'name' => 'Order Confirmation', 'enabled' => true },
            'relationships' => { 'latest_revision' => { 'data' => { 'id' => 'RE_STG', 'type' => 'revisions' } } }
          }
        ]
      }.to_json
    end

    def production_with_resources
      {
        'data' => library_payload('LB_PRD', 'Production Library'),
        'included' => []
      }.to_json
    end

    def stub_library_find(library_id, attrs)
      stub_request(:get, "https://reactor.adobe.io/libraries/#{library_id}")
        .to_return(
          status: 200,
          body: { 'data' => { 'id' => library_id, 'type' => 'libraries', 'attributes' => attrs } }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )
    end

    def stub_library_env(library_id, env_id)
      stub_request(:get, "https://reactor.adobe.io/libraries/#{library_id}/relationships/environment")
        .to_return(
          status: 200,
          body: { 'data' => { 'id' => env_id, 'type' => 'environments' } }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )
    end

    def stub_env_stage(env_id, stage)
      stub_request(:get, "https://reactor.adobe.io/environments/#{env_id}")
        .to_return(
          status: 200,
          body: { 'data' => { 'id' => env_id, 'type' => 'environments',
                              'attributes' => { 'stage' => stage } } }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )
    end

    before do
      stub_library_find('LB_DEV', library_attributes.merge('name' => 'Dev Library'))
      stub_library_find('LB_STG', library_attributes.merge('name' => 'Staging Library'))
      stub_library_find('LB_PRD', library_attributes.merge('name' => 'Production Library'))

      stub_request(:get, 'https://reactor.adobe.io/properties/PR123/libraries?page%5Bsize%5D=100')
        .to_return(
          status: 200,
          body: {
            'data' => [
              library_payload('LB_DEV', 'Dev Library'),
              library_payload('LB_STG', 'Staging Library'),
              library_payload('LB_PRD', 'Production Library')
            ],
            'links' => { 'next' => nil }
          }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )

      stub_library_env('LB_DEV', 'EN_DEV')
      stub_library_env('LB_STG', 'EN_STG')
      stub_library_env('LB_PRD', 'EN_PRD')
      stub_env_stage('EN_DEV',  'development')
      stub_env_stage('EN_STG',  'staging')
      stub_env_stage('EN_PRD', 'production')

      stub_request(:get, 'https://reactor.adobe.io/libraries/LB_DEV?include=rules%2Cdata_elements%2Cextensions')
        .to_return(status: 200, body: target_with_resources, headers: { 'Content-Type' => 'application/json' })
      stub_request(:get, 'https://reactor.adobe.io/libraries/LB_STG?include=rules%2Cdata_elements%2Cextensions')
        .to_return(status: 200, body: staging_with_resources, headers: { 'Content-Type' => 'application/json' })
      stub_request(:get, 'https://reactor.adobe.io/libraries/LB_PRD?include=rules%2Cdata_elements%2Cextensions')
        .to_return(status: 200, body: production_with_resources, headers: { 'Content-Type' => 'application/json' })

      stub_request(:get, 'https://reactor.adobe.io/revisions/RE_STG')
        .to_return(
          status: 200,
          body: {
            'data' => {
              'id' => 'RE_STG',
              'type' => 'revisions',
              'attributes' => { 'activity_type' => 'updated' },
              'relationships' => { 'entity' => { 'data' => { 'id' => 'RL123', 'type' => 'rules' } } }
            },
            'included' => [
              {
                'id' => 'RL123',
                'type' => 'rules',
                'attributes' => { 'name' => 'Order Confirmation', 'enabled' => true }
              }
            ]
          }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )
    end

    it 'returns an UpstreamChain wrapper' do
      expect(
        client.libraries.upstream_chain_for_resource('RL123', library_id: 'LB_DEV', property_id: 'PR123')
      ).to be_a(ReactorSDK::Resources::UpstreamChain)
    end

    it 'captures the target resource and target revision id' do
      result = client.libraries.upstream_chain_for_resource('RL123', library_id: 'LB_DEV', property_id: 'PR123')

      expect(result.target_resource).to be_a(ReactorSDK::Resources::Rule)
      expect(result.target_revision_id).to eq('RE_DEV')
    end

    it 'returns one entry per upstream library in order' do
      result = client.libraries.upstream_chain_for_resource('RL123', library_id: 'LB_DEV', property_id: 'PR123')

      expect(result.entries.map { |entry| [entry.library.id, entry.stage] }).to eq(
        [%w[LB_STG staging], %w[LB_PRD production]]
      )
    end

    it 'marks present and missing upstream matches correctly' do
      result = client.libraries.upstream_chain_for_resource('RL123', library_id: 'LB_DEV', property_id: 'PR123')

      expect(result.entries.first.present?).to be(true)
      expect(result.entries.first.revision_id).to eq('RE_STG')
      expect(result.entries.last.present?).to be(false)
      expect(result.entries.last.revision_id).to be_nil
    end

    it 'returns the nearest upstream match' do
      result = client.libraries.upstream_chain_for_resource('RL123', library_id: 'LB_DEV', property_id: 'PR123')

      expect(result.nearest_match.library.id).to eq('LB_STG')
      expect(result.nearest_match.entity_snapshot).to eq('name' => 'Order Confirmation', 'enabled' => true)
    end

    it 'accepts a typed resource object as the lookup input' do
      rule = ReactorSDK::Resources::Rule.new(
        id: 'RL123',
        type: 'rules',
        attributes: { 'name' => 'Order Confirmation', 'enabled' => true }
      )

      result = client.libraries.upstream_chain_for_resource(rule, library_id: 'LB_DEV', property_id: 'PR123')
      expect(result.resource_type).to eq('rules')
      expect(result.resource_id).to eq('RL123')
    end
  end

  describe '#find_snapshot' do
    let(:snapshot_response) do
      {
        'data' => {
          'id' => 'LB123',
          'type' => 'libraries',
          'attributes' => library_attributes
        },
        'included' => [
          {
            'id' => 'RL123',
            'type' => 'rules',
            'attributes' => { 'name' => 'Order Confirmation', 'enabled' => true },
            'relationships' => { 'latest_revision' => { 'data' => { 'id' => 'RE001', 'type' => 'revisions' } } }
          },
          {
            'id' => 'DE123',
            'type' => 'data_elements',
            'attributes' => {
              'name' => 'Page Name',
              'delegate_descriptor_id' => 'core::dataElements::custom-code',
              'settings' => '{"source":"return document.title;"}'
            },
            'relationships' => {
              'latest_revision' => { 'data' => { 'id' => 'RE010', 'type' => 'revisions' } },
              'extension' => { 'data' => { 'id' => 'EX123', 'type' => 'extensions' } }
            }
          },
          {
            'id' => 'EX123',
            'type' => 'extensions',
            'attributes' => {
              'name' => 'Core',
              'delegate_descriptor_id' => 'core::extension',
              'settings' => '{}'
            },
            'relationships' => { 'latest_revision' => { 'data' => { 'id' => 'RE020', 'type' => 'revisions' } } }
          }
        ]
      }.to_json
    end

    let(:rule_components_response) do
      jsonapi_list_response(
        type: 'rule_components',
        items: [
          {
            id: 'RC999',
            attributes: {
              'name' => 'Newer Component',
              'delegate_descriptor_id' => 'core::actions::custom-code',
              'settings' => '{"source":"console.log(2);","language":"javascript"}',
              'order' => 2,
              'rule_order' => 60.0
            }
          },
          {
            id: 'RC123',
            attributes: {
              'name' => 'Custom Code',
              'delegate_descriptor_id' => 'core::actions::custom-code',
              'settings' => '{"source":"console.log(_satellite.getVar(\'Page Name\'));","language":"javascript"}',
              'order' => 1,
              'rule_order' => 50.0
            }
          }
        ]
      ).tap do |payload|
        payload['data'].each do |item|
          item['relationships'] = {
            'extension' => { 'data' => { 'id' => 'EX123', 'type' => 'extensions' } },
            'latest_revision' => { 'data' => { 'id' => "RE_#{item['id']}", 'type' => 'revisions' } }
          }
        end
      end.to_json
    end

    let(:rule_revision_response) do
      {
        'data' => {
          'id' => 'RE001',
          'type' => 'revisions',
          'attributes' => { 'activity_type' => 'updated' },
          'relationships' => { 'entity' => { 'data' => { 'id' => 'RL123', 'type' => 'rules' } } }
        },
        'included' => [
          {
            'id' => 'RL123',
            'type' => 'rules',
            'attributes' => { 'name' => 'Order Confirmation', 'enabled' => true },
            'relationships' => {
              'rule_components' => {
                'data' => [{ 'id' => 'RC123', 'type' => 'rule_components' }]
              }
            }
          }
        ]
      }.to_json
    end

    before do
      stub_request(:get, 'https://reactor.adobe.io/libraries/LB123?include=rules%2Cdata_elements%2Cextensions')
        .to_return(status: 200, body: snapshot_response, headers: { 'Content-Type' => 'application/json' })
      stub_request(:get, 'https://reactor.adobe.io/rules/RL123/rule_components?page%5Bsize%5D=100')
        .to_return(status: 200, body: rule_components_response, headers: { 'Content-Type' => 'application/json' })
      stub_request(:get, 'https://reactor.adobe.io/revisions/RE001')
        .to_return(status: 200, body: rule_revision_response, headers: { 'Content-Type' => 'application/json' })
    end

    it 'returns a snapshot with associated rule components' do
      snapshot = client.libraries.find_snapshot('LB123', property_id: 'PR123')

      expect(snapshot).to be_a(ReactorSDK::Resources::LibrarySnapshot)
      expect(snapshot.rule_components_for_rule('RL123').map(&:id)).to eq(['RC123'])
      expect(snapshot.impacted_rules_for('DE123').map(&:id)).to eq(['RL123'])
    end

    it 'builds a fresh snapshot per call' do
      first = client.libraries.find_snapshot('LB123', property_id: 'PR123')
      second = client.libraries.find_snapshot('LB123', property_id: 'PR123')

      expect(first.object_id).not_to eq(second.object_id)
    end
  end

  describe '#compare' do
    def comparison_snapshot(library_id:, name:, rules: [], data_elements: [], extensions: [])
      library = ReactorSDK::Resources::LibraryWithResources.new(
        id: library_id,
        type: 'libraries',
        attributes: library_attributes.merge('name' => name),
        included_resources: {
          'rules' => rules,
          'data_elements' => data_elements,
          'extensions' => extensions
        }
      )

      ReactorSDK::Resources::LibrarySnapshot.new(
        property_id: 'PR123',
        library: library,
        rule_components_by_rule_id: {}
      )
    end

    def included_resource(id:, type:, name:, revision_id:)
      {
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
    end

    let(:current_snapshot) do
      comparison_snapshot(
        library_id: 'LB_DEV',
        name: 'Development Library',
        rules: [
          included_resource(id: 'RL100', type: 'rules', name: 'Checkout Rule', revision_id: 'RE_CUR_RULE'),
          included_resource(id: 'RL200', type: 'rules', name: 'Added Rule', revision_id: 'RE_ADDED')
        ],
        extensions: [
          included_resource(id: 'EX100', type: 'extensions', name: 'Core', revision_id: 'RE_EX')
        ]
      )
    end

    let(:baseline_snapshot) do
      comparison_snapshot(
        library_id: 'LB_STG',
        name: 'Staging Library',
        rules: [
          included_resource(id: 'RL100', type: 'rules', name: 'Checkout Rule', revision_id: 'RE_BASE_RULE')
        ],
        data_elements: [
          included_resource(id: 'DE200', type: 'data_elements', name: 'Removed Element', revision_id: 'RE_REMOVED')
        ],
        extensions: [
          included_resource(id: 'EX100', type: 'extensions', name: 'Core', revision_id: 'RE_EX')
        ]
      )
    end

    before do
      allow(client.libraries).to receive(:find_snapshot)
        .with('LB_DEV', property_id: 'PR123')
        .and_return(current_snapshot)
      allow(client.libraries).to receive(:find_snapshot)
        .with('LB_STG', property_id: 'PR123')
        .and_return(baseline_snapshot)
    end

    it 'returns a library comparison with revision-aware statuses' do
      comparison = client.libraries.compare('LB_DEV', baseline_library_id: 'LB_STG', property_id: 'PR123')

      expect(comparison).to be_a(ReactorSDK::Resources::LibraryComparison)
      expect(comparison.entries.to_h { |entry| [entry.resource_id, entry.status] }).to eq(
        'RL200' => 'added',
        'RL100' => 'modified',
        'DE200' => 'removed',
        'EX100' => 'unchanged'
      )
    end

    it 'builds Changeset-ready documents for changed resources' do
      comparison = client.libraries.compare('LB_DEV', baseline_library_id: 'LB_STG', property_id: 'PR123')

      expect(comparison.changeset_documents.map { |document| document[:path] }).to eq(
        %w[
          reactor/rules/RL200.json
          reactor/rules/RL100.json
          reactor/data_elements/DE200.json
        ]
      )
    end
  end

  describe '#comprehensive_upstream_chain_for_resource' do
    let(:dev_env_id)  { 'EN_DEV' }
    let(:stg_env_id)  { 'EN_STG' }
    let(:prod_env_id) { 'EN_PRD' }

    let(:dev_library) do
      { 'id' => 'LB_DEV', 'type' => 'libraries', 'attributes' => library_attributes.merge('name' => 'Dev Library') }
    end
    let(:stg_library) do
      { 'id' => 'LB_STG', 'type' => 'libraries', 'attributes' => library_attributes.merge('name' => 'Staging Library') }
    end
    let(:prod_library) do
      { 'id' => 'LB_PRD', 'type' => 'libraries', 'attributes' => library_attributes.merge('name' => 'Production Library') }
    end

    def stub_library_find(library_id, attrs)
      stub_request(:get, "https://reactor.adobe.io/libraries/#{library_id}")
        .to_return(
          status: 200,
          body: { 'data' => { 'id' => library_id, 'type' => 'libraries', 'attributes' => attrs } }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )
    end

    def stub_library_env(library_id, env_id)
      stub_request(:get, "https://reactor.adobe.io/libraries/#{library_id}/relationships/environment")
        .to_return(
          status: 200,
          body: { 'data' => { 'id' => env_id, 'type' => 'environments' } }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )
    end

    def stub_env_stage(env_id, stage)
      stub_request(:get, "https://reactor.adobe.io/environments/#{env_id}")
        .to_return(
          status: 200,
          body: { 'data' => { 'id' => env_id, 'type' => 'environments', 'attributes' => { 'stage' => stage } } }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )
    end

    before do
      stub_library_find('LB_DEV', library_attributes.merge('name' => 'Dev Library'))
      stub_library_find('LB_STG', library_attributes.merge('name' => 'Staging Library'))
      stub_library_find('LB_PRD', library_attributes.merge('name' => 'Production Library'))

      stub_request(:get, 'https://reactor.adobe.io/properties/PR123/libraries?page%5Bsize%5D=100')
        .to_return(
          status: 200,
          body: { 'data' => [dev_library, stg_library, prod_library], 'links' => { 'next' => nil } }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )

      stub_library_env('LB_DEV', dev_env_id)
      stub_library_env('LB_STG', stg_env_id)
      stub_library_env('LB_PRD', prod_env_id)
      stub_env_stage(dev_env_id, 'development')
      stub_env_stage(stg_env_id, 'staging')
      stub_env_stage(prod_env_id, 'production')

      stub_request(:get, 'https://reactor.adobe.io/libraries/LB_DEV?include=rules%2Cdata_elements%2Cextensions')
        .to_return(
          status: 200,
          body: {
            'data' => dev_library,
            'included' => [
              {
                'id' => 'RL123',
                'type' => 'rules',
                'attributes' => { 'name' => 'Order Confirmation', 'enabled' => true },
                'relationships' => { 'latest_revision' => { 'data' => { 'id' => 'RE_DEV', 'type' => 'revisions' } } }
              },
              {
                'id' => 'EX123',
                'type' => 'extensions',
                'attributes' => { 'name' => 'Core', 'delegate_descriptor_id' => 'core::extension', 'settings' => '{}' },
                'relationships' => { 'latest_revision' => { 'data' => { 'id' => 'RE_EX_DEV', 'type' => 'revisions' } } }
              }
            ]
          }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )

      stub_request(:get, 'https://reactor.adobe.io/libraries/LB_STG?include=rules%2Cdata_elements%2Cextensions')
        .to_return(
          status: 200,
          body: {
            'data' => stg_library,
            'included' => [
              {
                'id' => 'RL123',
                'type' => 'rules',
                'attributes' => { 'name' => 'Order Confirmation', 'enabled' => true },
                'relationships' => { 'latest_revision' => { 'data' => { 'id' => 'RE_STG', 'type' => 'revisions' } } }
              },
              {
                'id' => 'EX123',
                'type' => 'extensions',
                'attributes' => { 'name' => 'Core', 'delegate_descriptor_id' => 'core::extension', 'settings' => '{}' },
                'relationships' => { 'latest_revision' => { 'data' => { 'id' => 'RE_EX_STG', 'type' => 'revisions' } } }
              }
            ]
          }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )

      stub_request(:get, 'https://reactor.adobe.io/libraries/LB_PRD?include=rules%2Cdata_elements%2Cextensions')
        .to_return(
          status: 200,
          body: { 'data' => prod_library, 'included' => [] }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )

      stub_request(:get, 'https://reactor.adobe.io/rules/RL123/rule_components?page%5Bsize%5D=100')
        .to_return(
          status: 200,
          body: jsonapi_list_response(
            type: 'rule_components',
            items: [
              {
                id: 'RC123',
                attributes: {
                  'name' => 'Custom Code',
                  'delegate_descriptor_id' => 'core::actions::custom-code',
                  'settings' => '{"source":"console.log(1);","language":"javascript"}',
                  'order' => 1,
                  'rule_order' => 10.0
                }
              }
            ]
          ).tap do |payload|
            payload['data'].first['relationships'] = {
              'extension' => { 'data' => { 'id' => 'EX123', 'type' => 'extensions' } },
              'latest_revision' => { 'data' => { 'id' => 'RE_RC123', 'type' => 'revisions' } }
            }
          end.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )

      stub_request(:get, 'https://reactor.adobe.io/revisions/RE_DEV')
        .to_return(
          status: 200,
          body: {
            'data' => {
              'id' => 'RE_DEV',
              'type' => 'revisions',
              'attributes' => { 'activity_type' => 'updated' },
              'relationships' => { 'entity' => { 'data' => { 'id' => 'RL123', 'type' => 'rules' } } }
            },
            'included' => [
              {
                'id' => 'RL123',
                'type' => 'rules',
                'attributes' => { 'name' => 'Order Confirmation', 'enabled' => true },
                'relationships' => {
                  'rule_components' => {
                    'data' => [{ 'id' => 'RC123', 'type' => 'rule_components' }]
                  }
                }
              }
            ]
          }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )

      stub_request(:get, 'https://reactor.adobe.io/revisions/RE_STG')
        .to_return(
          status: 200,
          body: {
            'data' => {
              'id' => 'RE_STG',
              'type' => 'revisions',
              'attributes' => { 'activity_type' => 'updated' },
              'relationships' => { 'entity' => { 'data' => { 'id' => 'RL123', 'type' => 'rules' } } }
            },
            'included' => [
              {
                'id' => 'RL123',
                'type' => 'rules',
                'attributes' => { 'name' => 'Order Confirmation', 'enabled' => true },
                'relationships' => {
                  'rule_components' => {
                    'data' => [{ 'id' => 'RC123', 'type' => 'rule_components' }]
                  }
                }
              }
            ]
          }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )
    end

    it 'returns a comprehensive upstream chain with normalized entries' do
      result = client.libraries.comprehensive_upstream_chain_for_resource(
        'RL123',
        library_id: 'LB_DEV',
        property_id: 'PR123',
        resource_type: 'rules'
      )

      expect(result).to be_a(ReactorSDK::Resources::ComprehensiveUpstreamChain)
      expect(result.target_comprehensive_resource).to be_a(ReactorSDK::Resources::ComprehensiveRule)
      expect(result.target_comprehensive_resource.rule_components.map(&:id)).to eq(['RC123'])
      expect(result.nearest_match.library.id).to eq('LB_STG')
      expect(result.nearest_match.normalized_payload.dig('associations', 'rule_components').first['id']).to eq('RC123')
      expect(result.entries.last.present?).to be(false)
    end
  end
end
