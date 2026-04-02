# frozen_string_literal: true

require 'tempfile'

##
# @file spec/reactor_sdk/connection_spec.rb
# @description Direct tests for ReactorSDK::Connection.
#
#   Covers header injection, request serialization, response parsing,
#   and HTTP-to-error translation for the shared API connection layer.
#

RSpec.describe ReactorSDK::Connection do
  subject(:connection) { described_class.new(config, auth, rate_limiter) }

  let(:config) do
    instance_double(
      ReactorSDK::Configuration,
      base_url: 'https://reactor.adobe.io',
      timeout: 30,
      logger: nil,
      client_id: 'test_client_id',
      org_id: 'test_org_id'
    )
  end
  let(:auth) { instance_spy(ReactorSDK::Authentication, access_token: 'test_token') }
  let(:rate_limiter) { instance_spy(ReactorSDK::RateLimiter) }
  let(:build_response) do
    lambda do |status:, body:, headers: {}, path: '/properties/PR123', request_method: :get|
      env = instance_double(
        Faraday::Env,
        url: URI("https://reactor.adobe.io#{path}"),
        method: request_method
      )

      instance_double(Faraday::Response, status: status, body: body, headers: headers, env: env)
    end
  end

  describe '#get' do
    before do
      stub_request(:get, 'https://reactor.adobe.io/properties/PR123')
        .with(query: { 'filter[name]' => 'Marketing Site' })
        .to_return(
          status: 200,
          body: jsonapi_response(
            type: 'properties',
            id: 'PR123',
            attributes: { 'name' => 'Marketing Site' }
          ).to_json,
          headers: { 'Content-Type' => 'application/json' }
        )
    end

    it 'injects auth headers, rate limits the call, and parses JSON' do
      result = connection.get('/properties/PR123', params: { 'filter[name]' => 'Marketing Site' })

      expect(result.dig('data', 'id')).to eq('PR123')
      expect(rate_limiter).to have_received(:acquire).once
      expect(WebMock).to have_requested(:get, 'https://reactor.adobe.io/properties/PR123')
        .with(
          query: { 'filter[name]' => 'Marketing Site' },
          headers: {
            'Authorization' => 'Bearer test_token',
            'x-api-key' => 'test_client_id',
            'x-gw-ims-org-id' => 'test_org_id',
            'Accept' => described_class::ACCEPT_HEADER,
            'Content-Type' => described_class::CONTENT_TYPE
          }
        )
    end
  end

  describe '#post' do
    before do
      stub_request(:post, 'https://reactor.adobe.io/properties')
        .to_return(
          status: 201,
          body: jsonapi_response(
            type: 'properties',
            id: 'PR123',
            attributes: { 'name' => 'Marketing Site' }
          ).to_json,
          headers: { 'Content-Type' => 'application/json' }
        )
    end

    it 'serializes the request body as JSON' do
      connection.post('/properties', data: { type: 'properties', attributes: { name: 'Marketing Site' } })

      expect(WebMock).to have_requested(:post, 'https://reactor.adobe.io/properties')
        .with(body: { data: { type: 'properties', attributes: { name: 'Marketing Site' } } }.to_json)
    end
  end

  describe '#post_multipart' do
    let!(:package_file) do
      Tempfile.new(['extension-package', '.zip']).tap do |file|
        file.write('zip-bytes')
        file.rewind
      end
    end

    after do
      package_file.close!
    end

    before do
      stub_request(:post, 'https://reactor.adobe.io/extension_packages')
        .to_return(
          status: 202,
          body: jsonapi_response(
            type: 'extension_packages',
            id: 'EP123',
            attributes: { 'name' => 'acme-extension', 'version' => '1.0.0' }
          ).to_json,
          headers: { 'Content-Type' => 'application/json' }
        )
    end

    it 'uploads multipart form data without forcing the JSON content type' do
      result = connection.post_multipart('/extension_packages', file_path: package_file.path)

      expect(result.dig('data', 'id')).to eq('EP123')
      expect(WebMock).to(
        have_requested(:post, 'https://reactor.adobe.io/extension_packages')
          .with { |request| request.headers['Content-Type'].include?('multipart/form-data') }
      )
    end
  end

  describe '#delete_relationship' do
    before do
      stub_request(:delete, 'https://reactor.adobe.io/libraries/LB123/relationships/rules')
        .to_return(status: 204, body: '')
    end

    it 'sends a JSON body with the delete request' do
      result = connection.delete_relationship(
        '/libraries/LB123/relationships/rules',
        data: [{ id: 'RL123', type: 'rules' }]
      )

      expect(result).to be_nil
      expect(WebMock).to have_requested(
        :delete,
        'https://reactor.adobe.io/libraries/LB123/relationships/rules'
      ).with(body: { data: [{ id: 'RL123', type: 'rules' }] }.to_json)
    end
  end

  describe '#handle_response (private)' do
    it 'returns nil for 204 responses' do
      response = build_response.call(status: 204, body: '')

      expect(connection.send(:handle_response, response)).to be_nil
    end

    it 'returns parsed JSON for successful responses' do
      response = build_response.call(
        status: 200,
        body: { data: { id: 'PR123', type: 'properties' } }.to_json
      )

      expect(connection.send(:handle_response, response)).to eq(
        'data' => { 'id' => 'PR123', 'type' => 'properties' }
      )
    end

    it 'raises UnprocessableEntityError with validation errors for 422 responses' do
      response = build_response.call(
        status: 422,
        body: { errors: [{ detail: 'name is required' }] }.to_json
      )

      expect do
        connection.send(:handle_response, response)
      end.to raise_error(ReactorSDK::UnprocessableEntityError, 'name is required')

      begin
        connection.send(:handle_response, response)
      rescue ReactorSDK::UnprocessableEntityError => e
        expect(e.validation_errors).to eq([{ 'detail' => 'name is required' }])
        expect(e.status).to eq(422)
      end
    end

    it 'raises AuthenticationError for 401 responses' do
      response = build_response.call(status: 401, body: { errors: [] }.to_json)

      expect do
        connection.send(:handle_response, response)
      end.to raise_error(ReactorSDK::AuthenticationError, /Unauthorized/)
    end

    it 'raises AuthorizationError for 403 responses' do
      response = build_response.call(status: 403, body: { errors: [] }.to_json)

      expect do
        connection.send(:handle_response, response)
      end.to raise_error(ReactorSDK::AuthorizationError, /Forbidden/)
    end

    it 'raises ResourceNotFoundError for 404 responses' do
      response = build_response.call(
        status: 404,
        body: { errors: [] }.to_json,
        path: '/properties/PR999'
      )

      expect do
        connection.send(:handle_response, response)
      end.to raise_error(ReactorSDK::ResourceNotFoundError, %r{Resource not found: /properties/PR999})
    end

    it 'raises a descriptive generic error for 405 responses' do
      response = build_response.call(
        status: 405,
        body: { errors: [] }.to_json,
        path: '/libraries/LB123',
        request_method: :patch
      )

      expect do
        connection.send(:handle_response, response)
      end.to raise_error(ReactorSDK::Error, %r{Adobe returned 405 for PATCH /libraries/LB123})
    end

    it 'raises a conflict error using Adobe detail when present' do
      response = build_response.call(
        status: 409,
        body: { errors: [{ detail: 'Revision conflict detected' }] }.to_json
      )

      expect do
        connection.send(:handle_response, response)
      end.to raise_error(ReactorSDK::Error, 'Revision conflict detected')
    end

    it 'raises RateLimitError with retry_after for 429 responses' do
      response = build_response.call(
        status: 429,
        body: { errors: [] }.to_json,
        headers: { 'Retry-After' => '15' }
      )

      expect do
        connection.send(:handle_response, response)
      end.to raise_error(ReactorSDK::RateLimitError)

      begin
        connection.send(:handle_response, response)
      rescue ReactorSDK::RateLimitError => e
        expect(e.retry_after).to eq(15)
        expect(e.status).to eq(429)
      end
    end

    it 'raises ServerError for 5xx responses' do
      response = build_response.call(status: 503, body: { errors: [] }.to_json)

      expect do
        connection.send(:handle_response, response)
      end.to raise_error(ReactorSDK::ServerError, /HTTP 503/)
    end

    it 'raises ParseError for invalid JSON bodies' do
      response = build_response.call(status: 200, body: 'not-json')

      expect do
        connection.send(:handle_response, response)
      end.to raise_error(ReactorSDK::ParseError, 'Could not parse API response as JSON')
    end
  end
end
