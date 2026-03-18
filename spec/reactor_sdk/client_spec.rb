# frozen_string_literal: true

##
# @file spec/reactor_sdk/client_spec.rb
# @description Tests for ReactorSDK::Client.
#
#   Covers: initialization, credential validation, all endpoint
#   group availability, and config exposure.
#

RSpec.describe ReactorSDK::Client do
  let(:valid_params) do
    {
      client_id:     "test_client_id",
      client_secret: "test_client_secret",
      org_id:        "test_org_id",
      ims_token_url: "http://localhost:9292/token"
    }
  end

  before do
    stub_request(:post, "http://localhost:9292/token")
      .to_return(
        status:  200,
        body:    { access_token: "test_token", expires_in: 86_400 }.to_json,
        headers: { "Content-Type" => "application/json" }
      )
  end

  describe "#initialize" do
    subject(:client) { described_class.new(**valid_params) }

    it "creates a client successfully" do
      expect(client).to be_a(ReactorSDK::Client)
    end

    it "exposes the configuration" do
      expect(client.config).to be_a(ReactorSDK::Configuration)
    end

    it "stores the org_id on the config" do
      expect(client.config.org_id).to eq("test_org_id")
    end

    it "raises ConfigurationError when client_id is blank" do
      expect {
        described_class.new(**valid_params.merge(client_id: ""))
      }.to raise_error(ReactorSDK::ConfigurationError)
    end
  end

  describe "endpoint groups" do
    subject(:client) { described_class.new(**valid_params) }

    it "exposes companies endpoint" do
      expect(client.companies).to be_a(ReactorSDK::Endpoints::Companies)
    end

    it "exposes properties endpoint" do
      expect(client.properties).to be_a(ReactorSDK::Endpoints::Properties)
    end

    it "exposes environments endpoint" do
      expect(client.environments).to be_a(ReactorSDK::Endpoints::Environments)
    end

    it "exposes rules endpoint" do
      expect(client.rules).to be_a(ReactorSDK::Endpoints::Rules)
    end

    it "exposes rule_components endpoint" do
      expect(client.rule_components).to be_a(ReactorSDK::Endpoints::RuleComponents)
    end

    it "exposes data_elements endpoint" do
      expect(client.data_elements).to be_a(ReactorSDK::Endpoints::DataElements)
    end

    it "exposes extensions endpoint" do
      expect(client.extensions).to be_a(ReactorSDK::Endpoints::Extensions)
    end

    it "exposes libraries endpoint" do
      expect(client.libraries).to be_a(ReactorSDK::Endpoints::Libraries)
    end

    it "exposes builds endpoint" do
      expect(client.builds).to be_a(ReactorSDK::Endpoints::Builds)
    end

    it "exposes audit_events endpoint" do
      expect(client.audit_events).to be_a(ReactorSDK::Endpoints::AuditEvents)
    end

    it "exposes revisions endpoint" do
      expect(client.revisions).to be_a(ReactorSDK::Endpoints::Revisions)
    end
  end
end
