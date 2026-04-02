# frozen_string_literal: true

RSpec.describe ReactorSDK::Endpoints::Notes do
  subject(:client) { test_client }

  describe '#find' do
    before do
      stub_request(:get, 'https://reactor.adobe.io/notes/NT123')
        .to_return(
          status: 200,
          body: jsonapi_response(
            type: 'notes',
            id: 'NT123',
            attributes: { 'text' => 'Shipped to prod' }
          ).to_json,
          headers: { 'Content-Type' => 'application/json' }
        )
    end

    it 'returns a note resource' do
      result = client.notes.find('NT123')

      expect(result).to be_a(ReactorSDK::Resources::Note)
      expect(result.text).to eq('Shipped to prod')
    end
  end
end
