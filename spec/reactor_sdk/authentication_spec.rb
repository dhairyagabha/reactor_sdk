# frozen_string_literal: true

##
# @file spec/reactor_sdk/authentication_spec.rb
# @description Tests for ReactorSDK::Authentication.
#
#   Authentication is tested indirectly through all endpoint specs —
#   every test_client stub covers the token fetch flow via WebMock.
#
#   Direct unit tests for token refresh, expiry buffer, and thread
#   safety are candidates for a future dedicated test suite using
#   VCR cassettes recorded against the real Adobe IMS endpoint.
#

RSpec.describe ReactorSDK::Authentication do
  subject(:auth) { described_class.new(config) }

  let(:config) do
    ReactorSDK::Configuration.new(
      client_id: 'test_client_id',
      client_secret: 'test_client_secret',
      org_id: 'test_org_id',
      ims_token_url: 'http://localhost:9292/token'
    )
  end

  describe 'constants' do
    it 'has the correct IMS token URL' do
      expect(described_class::IMS_TOKEN_URL).to eq(
        'https://ims-na1.adobelogin.com/ims/token/v3'
      )
    end

    it 'has a 5 minute refresh buffer' do
      expect(described_class::REFRESH_BUFFER_SECONDS).to eq(300)
    end

    it 'has the correct OAuth scope' do
      expect(described_class::REACTOR_SCOPE).to include('openid')
      expect(described_class::REACTOR_SCOPE).to include('AdobeID')
    end
  end

  describe '#access_token' do
    context 'when the token fetch succeeds' do
      before do
        stub_request(:post, 'http://localhost:9292/token')
          .to_return(
            status: 200,
            body: { access_token: 'fresh_token', expires_in: 86_400 }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'returns the access token' do
        expect(auth.access_token).to eq('fresh_token')
      end

      it 'caches the token on subsequent calls' do
        auth.access_token
        auth.access_token
        expect(WebMock).to have_requested(:post, 'http://localhost:9292/token').once
      end

      it 'refreshes an expired cached token when auto refresh is enabled' do
        stub_request(:post, 'http://localhost:9292/token')
          .to_return(
            { status: 200, body: { access_token: 'fresh_token', expires_in: 86_400 }.to_json,
              headers: { 'Content-Type' => 'application/json' } },
            { status: 200, body: { access_token: 'refreshed_token', expires_in: 86_400 }.to_json,
              headers: { 'Content-Type' => 'application/json' } }
          )

        expect(auth.access_token).to eq('fresh_token')

        auth.instance_variable_set(:@token_expiry, Time.now.utc - 1)

        expect(auth.access_token).to eq('refreshed_token')
        expect(WebMock).to have_requested(:post, 'http://localhost:9292/token').twice
      end
    end

    context 'when the token fetch fails' do
      before do
        stub_request(:post, 'http://localhost:9292/token')
          .to_return(status: 401, body: { error: 'invalid_client' }.to_json)
      end

      it 'raises AuthenticationError' do
        expect { auth.access_token }.to raise_error(ReactorSDK::AuthenticationError)
      end

      it 'includes the HTTP status in the error' do
        expect { auth.access_token }
          .to raise_error(ReactorSDK::AuthenticationError) do |e|
            expect(e.status).to eq(401)
          end
      end
    end

    context 'when auto_refresh_token is disabled' do
      let(:config) do
        ReactorSDK::Configuration.new(
          client_id: 'test_client_id',
          client_secret: 'test_client_secret',
          org_id: 'test_org_id',
          ims_token_url: 'http://localhost:9292/token',
          auto_refresh_token: false
        )
      end

      before do
        stub_request(:post, 'http://localhost:9292/token')
          .to_return(
            status: 200,
            body: { access_token: 'fresh_token', expires_in: 86_400 }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'still fetches the initial token' do
        expect(auth.access_token).to eq('fresh_token')
      end

      it 'raises when a cached token has expired' do
        auth.access_token
        auth.instance_variable_set(:@token_expiry, Time.now.utc - 1)

        expect { auth.access_token }
          .to raise_error(ReactorSDK::AuthenticationError, /auto_refresh_token is disabled/)
        expect(WebMock).to have_requested(:post, 'http://localhost:9292/token').once
      end
    end
  end
end
