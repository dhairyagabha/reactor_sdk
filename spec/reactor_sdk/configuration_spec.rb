# frozen_string_literal: true

##
# @file spec/reactor_sdk/configuration_spec.rb
# @description Tests for ReactorSDK::Configuration.
#
#   Covers: required field validation, default values,
#   optional overrides, and the ims_token_url test helper.
#

RSpec.describe ReactorSDK::Configuration do
  let(:valid_params) do
    {
      client_id: 'test_client_id',
      client_secret: 'test_client_secret',
      org_id: 'test_org_id'
    }
  end

  describe '#initialize' do
    context 'with valid credentials' do
      subject(:config) { described_class.new(**valid_params) }

      it 'sets client_id' do
        expect(config.client_id).to eq('test_client_id')
      end

      it 'sets client_secret' do
        expect(config.client_secret).to eq('test_client_secret')
      end

      it 'sets org_id' do
        expect(config.org_id).to eq('test_org_id')
      end

      it 'uses the default base_url' do
        expect(config.base_url).to eq('https://reactor.adobe.io')
      end

      it 'uses the default timeout' do
        expect(config.timeout).to eq(30)
      end

      it 'sets auto_refresh_token to true by default' do
        expect(config.auto_refresh_token).to be(true)
      end

      it 'sets logger to nil by default' do
        expect(config.logger).to be_nil
      end

      it 'uses the real IMS token URL by default' do
        expect(config.ims_token_url).to eq(
          ReactorSDK::Authentication::IMS_TOKEN_URL
        )
      end
    end

    context 'with optional overrides' do
      it 'accepts a custom base_url' do
        config = described_class.new(**valid_params, base_url: 'https://custom.example.com')
        expect(config.base_url).to eq('https://custom.example.com')
      end

      it 'accepts a custom ims_token_url for testing' do
        config = described_class.new(**valid_params, ims_token_url: 'http://localhost:9292/token')
        expect(config.ims_token_url).to eq('http://localhost:9292/token')
      end

      it 'accepts a custom timeout' do
        config = described_class.new(**valid_params, timeout: 60)
        expect(config.timeout).to eq(60)
      end

      it 'accepts auto_refresh_token: false' do
        config = described_class.new(**valid_params, auto_refresh_token: false)
        expect(config.auto_refresh_token).to be(false)
      end
    end

    context 'with missing required fields' do
      it 'raises ConfigurationError when client_id is blank' do
        expect do
          described_class.new(**valid_params, client_id: '')
        end.to raise_error(ReactorSDK::ConfigurationError, /client_id/)
      end

      it 'raises ConfigurationError when client_secret is blank' do
        expect do
          described_class.new(**valid_params, client_secret: '')
        end.to raise_error(ReactorSDK::ConfigurationError, /client_secret/)
      end

      it 'raises ConfigurationError when org_id is blank' do
        expect do
          described_class.new(**valid_params, org_id: '')
        end.to raise_error(ReactorSDK::ConfigurationError, /org_id/)
      end

      it 'raises ConfigurationError when client_id is nil' do
        expect do
          described_class.new(**valid_params, client_id: nil)
        end.to raise_error(ReactorSDK::ConfigurationError, /client_id/)
      end
    end
  end
end
