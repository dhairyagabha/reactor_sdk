# frozen_string_literal: true

RSpec.describe ReactorSDK::Endpoints::Profiles do
  subject(:client) { test_client }

  describe '#current' do
    let(:response_body) do
      {
        'data' => {
          'id' => 'PF123',
          'type' => 'profiles',
          'attributes' => {
            'active_org' => 'ORG123@AdobeOrg',
            'display_name' => 'Test User',
            'email' => 'test@example.com'
          }
        },
        'meta' => { 'rights' => ['develop_extensions'] }
      }.to_json
    end

    before do
      stub_request(:get, 'https://reactor.adobe.io/profile')
        .to_return(
          status: 200,
          body: response_body,
          headers: { 'Content-Type' => 'application/json' }
        )
    end

    it 'returns the current user profile' do
      result = client.profiles.current

      expect(result).to be_a(ReactorSDK::Resources::Profile)
      expect(result.email).to eq('test@example.com')
      expect(result.rights).to eq(['develop_extensions'])
    end
  end
end
