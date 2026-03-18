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
end
