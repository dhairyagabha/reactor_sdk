# frozen_string_literal: true

##
# @file spec/reactor_sdk/endpoints/base_endpoint_spec.rb
# @description Direct tests for ReactorSDK::Endpoints::BaseEndpoint.
#
#   Covers payload helpers and the shared CRUD helper methods used by
#   every endpoint implementation in the SDK.
#

RSpec.describe ReactorSDK::Endpoints::BaseEndpoint do
  subject(:endpoint) do
    endpoint_class.new(connection: connection, paginator: paginator, parser: parser)
  end

  let(:connection) { instance_spy(ReactorSDK::Connection) }
  let(:paginator) { instance_spy(ReactorSDK::Paginator) }
  let(:parser) { instance_spy(ReactorSDK::ResponseParser) }

  let(:endpoint_class) do
    stub_const(
      'SpecBaseEndpointHarness',
      Class.new(described_class) do
        public(
          *%i[
            build_payload
            build_relationship_payload
            fetch_resource
            list_resources
            create_resource
            update_resource
            delete_resource
            fetch_relationship
            create_note_for_path
          ]
        )
      end
    )
  end

  describe '#build_payload' do
    it 'builds a JSON:API payload with optional id, relationships, and meta' do
      payload = endpoint.build_payload(
        'properties',
        { name: 'Marketing Site' },
        id: 'PR123',
        relationships: { company: { data: { id: 'CO123', type: 'companies' } } },
        meta: { action: 'submit' }
      )

      expect(payload).to eq(
        data: {
          id: 'PR123',
          type: 'properties',
          attributes: { name: 'Marketing Site' },
          relationships: { company: { data: { id: 'CO123', type: 'companies' } } },
          meta: { action: 'submit' }
        }
      )
    end
  end

  describe '#build_relationship_payload' do
    it 'normalizes ids into JSON:API relationship data' do
      payload = endpoint.build_relationship_payload('rules', %w[RL123 RL456])

      expect(payload).to eq(
        data: [
          { id: 'RL123', type: 'rules' },
          { id: 'RL456', type: 'rules' }
        ]
      )
    end
  end

  describe '#fetch_resource' do
    let(:response) { { 'data' => { 'id' => 'PR123' } } }
    let(:resource) { instance_double(ReactorSDK::Resources::Property) }

    it 'fetches and parses a single resource' do
      allow(connection).to receive(:get)
        .with('/properties/PR123', params: { include: 'company' })
        .and_return(response)
      allow(parser).to receive(:parse)
        .with(response['data'], ReactorSDK::Resources::Property, response: response)
        .and_return(resource)

      result = endpoint.fetch_resource(
        '/properties/PR123',
        ReactorSDK::Resources::Property,
        params: { include: 'company' }
      )

      expect(result).to eq(resource)
      expect(connection).to have_received(:get)
        .with('/properties/PR123', params: { include: 'company' })
      expect(parser).to have_received(:parse)
        .with(response['data'], ReactorSDK::Resources::Property, response: response)
    end
  end

  describe '#list_resources' do
    let(:records) { [{ 'id' => 'PR123' }, { 'id' => 'PR456' }] }
    let(:resources) { [instance_double(ReactorSDK::Resources::Property)] }

    it 'delegates pagination and parses the resulting collection' do
      allow(paginator).to receive(:all)
        .with('/companies/CO123/properties', params: { include: 'library' })
        .and_return(records)
      allow(parser).to receive(:parse_many)
        .with(records, ReactorSDK::Resources::Property)
        .and_return(resources)

      result = endpoint.list_resources(
        '/companies/CO123/properties',
        ReactorSDK::Resources::Property,
        params: { include: 'library' }
      )

      expect(result).to eq(resources)
      expect(paginator).to have_received(:all)
        .with('/companies/CO123/properties', params: { include: 'library' })
      expect(parser).to have_received(:parse_many)
        .with(records, ReactorSDK::Resources::Property)
    end
  end

  describe '#create_resource' do
    let(:response) { { 'data' => { 'id' => 'PR123' } } }
    let(:resource) { instance_double(ReactorSDK::Resources::Property) }
    let(:expected_payload) do
      {
        data: {
          type: 'properties',
          attributes: { name: 'Marketing Site' }
        }
      }
    end

    it 'posts a JSON:API payload and parses the created resource' do
      allow(connection).to receive(:post)
        .with('/companies/CO123/properties', expected_payload)
        .and_return(response)
      allow(parser).to receive(:parse)
        .with(response['data'], ReactorSDK::Resources::Property, response: response)
        .and_return(resource)

      result = endpoint.create_resource(
        '/companies/CO123/properties',
        'properties',
        ReactorSDK::Resources::Property,
        attributes: { name: 'Marketing Site' }
      )

      expect(result).to eq(resource)
      expect(connection).to have_received(:post)
        .with('/companies/CO123/properties', expected_payload)
      expect(parser).to have_received(:parse)
        .with(response['data'], ReactorSDK::Resources::Property, response: response)
    end
  end

  describe '#update_resource' do
    let(:response) { { 'data' => { 'id' => 'PR123' } } }
    let(:resource) { instance_double(ReactorSDK::Resources::Property) }
    let(:expected_payload) do
      {
        data: {
          id: 'PR123',
          type: 'properties',
          attributes: { name: 'Renamed Property' }
        }
      }
    end

    it 'patches a JSON:API payload and parses the updated resource' do
      allow(connection).to receive(:patch)
        .with('/properties/PR123', expected_payload)
        .and_return(response)
      allow(parser).to receive(:parse)
        .with(response['data'], ReactorSDK::Resources::Property, response: response)
        .and_return(resource)

      result = endpoint.update_resource(
        '/properties/PR123',
        'PR123',
        'properties',
        ReactorSDK::Resources::Property,
        attributes: { name: 'Renamed Property' }
      )

      expect(result).to eq(resource)
      expect(connection).to have_received(:patch)
        .with('/properties/PR123', expected_payload)
      expect(parser).to have_received(:parse)
        .with(response['data'], ReactorSDK::Resources::Property, response: response)
    end
  end

  describe '#delete_resource' do
    it 'deletes a resource and returns nil' do
      allow(connection).to receive(:delete).with('/properties/PR123')

      expect(endpoint.delete_resource('/properties/PR123')).to be_nil
      expect(connection).to have_received(:delete).with('/properties/PR123')
    end
  end

  describe '#fetch_relationship' do
    it 'returns the relationship linkage data' do
      allow(connection).to receive(:get)
        .with('/libraries/LB123/relationships/rules', params: { include: 'rules' })
        .and_return('data' => [{ 'id' => 'RL123' }])

      result = endpoint.fetch_relationship(
        '/libraries/LB123/relationships/rules',
        params: { include: 'rules' }
      )

      expect(result).to eq([{ 'id' => 'RL123' }])
      expect(connection).to have_received(:get)
        .with('/libraries/LB123/relationships/rules', params: { include: 'rules' })
    end
  end

  describe '#create_note_for_path' do
    let(:response) { { 'data' => { 'id' => 'NT123' } } }
    let(:note) { instance_double(ReactorSDK::Resources::Note) }
    let(:expected_payload) do
      {
        data: {
          type: 'notes',
          attributes: { text: 'Ready for approval' }
        }
      }
    end

    it 'creates and parses a note resource' do
      allow(connection).to receive(:post)
        .with('/properties/PR123/notes', expected_payload)
        .and_return(response)
      allow(parser).to receive(:parse)
        .with(response['data'], ReactorSDK::Resources::Note, response: response)
        .and_return(note)

      result = endpoint.create_note_for_path('/properties/PR123/notes', 'Ready for approval')

      expect(result).to eq(note)
      expect(connection).to have_received(:post)
        .with('/properties/PR123/notes', expected_payload)
      expect(parser).to have_received(:parse)
        .with(response['data'], ReactorSDK::Resources::Note, response: response)
    end
  end
end
