# frozen_string_literal: true

##
# @file spec/reactor_sdk/endpoints/audit_events_spec.rb
# @description Tests for ReactorSDK::Endpoints::AuditEvents.
#
#   Covers: list, filtered list, find, and error handling.
#

RSpec.describe ReactorSDK::Endpoints::AuditEvents do
  subject(:client) { test_client }

  let(:audit_event_attributes) do
    {
      'type_of' => 'rule.updated',
      'entity_display_name' => 'Order Confirmation',
      'created_at' => '2024-01-02T00:00:00.000Z',
      'previous_attributes' => { name: 'Old Name' },
      'updated_attributes' => { name: 'Order Confirmation' }
    }
  end

  let(:single_response) do
    jsonapi_response(
      type: 'audit_events',
      id: 'AE123',
      attributes: audit_event_attributes
    ).to_json
  end

  let(:list_response) do
    jsonapi_list_response(
      type: 'audit_events',
      items: [
        { id: 'AE123', attributes: audit_event_attributes },
        { id: 'AE456', attributes: audit_event_attributes.merge('type_of' => 'rule.created') }
      ]
    ).to_json
  end

  describe '#list_for_property' do
    before do
      stub_request(:get, 'https://reactor.adobe.io/properties/PR123/audit_events?page%5Bsize%5D=100')
        .to_return(status: 200, body: list_response, headers: { 'Content-Type' => 'application/json' })
    end

    it 'returns an array of AuditEvent resources' do
      result = client.audit_events.list_for_property('PR123')
      expect(result).to all(be_a(ReactorSDK::Resources::AuditEvent))
    end

    it 'returns the correct number of audit events' do
      result = client.audit_events.list_for_property('PR123')
      expect(result.length).to eq(2)
    end

    it 'maps attributes to Ruby methods' do
      result = client.audit_events.list_for_property('PR123')
      expect(result.first.type_of).to eq('rule.updated')
      expect(result.first.entity_display_name).to eq('Order Confirmation')
    end
  end

  describe '#list_for_property with a since filter' do
    before do
      stub_request(
        :get,
        'https://reactor.adobe.io/properties/PR123/audit_events?page%5Bsize%5D=100&filter%5Bcreated_at%5D=GT+2024-01-01T00%3A00%3A00Z'
      ).to_return(status: 200, body: list_response, headers: { 'Content-Type' => 'application/json' })
    end

    it 'passes the created_at filter through to the API' do
      result = client.audit_events.list_for_property('PR123', since: '2024-01-01T00:00:00Z')
      expect(result.length).to eq(2)
    end
  end

  describe '#find' do
    before do
      stub_request(:get, 'https://reactor.adobe.io/audit_events/AE123')
        .to_return(status: 200, body: single_response, headers: { 'Content-Type' => 'application/json' })
    end

    it 'returns an AuditEvent resource' do
      result = client.audit_events.find('AE123')
      expect(result).to be_a(ReactorSDK::Resources::AuditEvent)
    end

    it 'maps the id correctly' do
      result = client.audit_events.find('AE123')
      expect(result.id).to eq('AE123')
    end

    context 'when the audit event does not exist' do
      before do
        stub_request(:get, 'https://reactor.adobe.io/audit_events/AE_INVALID')
          .to_return(status: 404, body: { errors: [] }.to_json)
      end

      it 'raises ResourceNotFoundError' do
        expect do
          client.audit_events.find('AE_INVALID')
        end.to raise_error(ReactorSDK::ResourceNotFoundError)
      end
    end
  end
end
