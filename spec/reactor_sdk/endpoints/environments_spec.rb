# frozen_string_literal: true

##
# @file spec/reactor_sdk/endpoints/environments_spec.rb
# @description Tests for ReactorSDK::Endpoints::Environments.
#
#   Covers: list, find, create, delete, and error handling.
#   Environment creation is especially important for LaunchGuard —
#   it is how personal developer sandboxes are provisioned.
#

RSpec.describe ReactorSDK::Endpoints::Environments do
  subject(:client) { test_client }

  let(:environment_attributes) do
    {
      "name" => "Development",
      "stage" => "development",
      "archived" => false,
      "created_at" => "2024-01-01T00:00:00.000Z",
      "updated_at" => "2024-01-01T00:00:00.000Z"
    }
  end

  let(:single_response) do
    jsonapi_response(
      type: "environments",
      id: "EN123",
      attributes: environment_attributes
    ).to_json
  end

  let(:list_response) do
    jsonapi_list_response(
      type: "environments",
      items: [
        { id: "EN123", attributes: environment_attributes },
        { id: "EN456", attributes: environment_attributes.merge("name" => "Staging", "stage" => "staging") },
        { id: "EN789", attributes: environment_attributes.merge("name" => "Production", "stage" => "production") }
      ]
    ).to_json
  end

  describe "#list_for_property" do
    before do
      stub_request(:get, "https://reactor.adobe.io/properties/PR123/environments?page%5Bsize%5D=100")
        .to_return(status: 200, body: list_response, headers: { "Content-Type" => "application/json" })
    end

    it "returns an array of Environment resources" do
      result = client.environments.list_for_property("PR123")
      expect(result).to all(be_a(ReactorSDK::Resources::Environment))
    end

    it "returns the correct number of environments" do
      result = client.environments.list_for_property("PR123")
      expect(result.length).to eq(3)
    end

    it "maps attributes to Ruby methods" do
      result = client.environments.list_for_property("PR123")
      expect(result.first.name).to eq("Development")
      expect(result.first.stage).to eq("development")
      expect(result.first.archived?).to be(false)
    end

    it "returns the correct ids" do
      result = client.environments.list_for_property("PR123")
      expect(result.map(&:id)).to eq(%w[EN123 EN456 EN789])
    end
  end

  describe "#find" do
    before do
      stub_request(:get, "https://reactor.adobe.io/environments/EN123")
        .to_return(status: 200, body: single_response, headers: { "Content-Type" => "application/json" })
    end

    it "returns an Environment resource" do
      result = client.environments.find("EN123")
      expect(result).to be_a(ReactorSDK::Resources::Environment)
    end

    it "maps the id correctly" do
      result = client.environments.find("EN123")
      expect(result.id).to eq("EN123")
    end

    it "maps attributes to Ruby methods" do
      result = client.environments.find("EN123")
      expect(result.name).to eq("Development")
      expect(result.stage).to eq("development")
    end

    context "when the environment does not exist" do
      before do
        stub_request(:get, "https://reactor.adobe.io/environments/EN_INVALID")
          .to_return(status: 404, body: { errors: [] }.to_json)
      end

      it "raises ResourceNotFoundError" do
        expect do
          client.environments.find("EN_INVALID")
        end.to raise_error(ReactorSDK::ResourceNotFoundError)
      end
    end
  end

  describe "#create" do
    before do
      stub_request(:post, "https://reactor.adobe.io/properties/PR123/environments")
        .to_return(status: 201, body: single_response, headers: { "Content-Type" => "application/json" })
    end

    it "returns an Environment resource" do
      result = client.environments.create(property_id: "PR123", name: "jsmith-dev")
      expect(result).to be_a(ReactorSDK::Resources::Environment)
    end

    it "maps attributes on the returned resource" do
      result = client.environments.create(property_id: "PR123", name: "jsmith-dev")
      expect(result.name).to eq("Development")
      expect(result.stage).to eq("development")
    end

    it "sends the correct payload" do
      client.environments.create(property_id: "PR123", name: "jsmith-dev")
      expect(WebMock).to have_requested(:post, "https://reactor.adobe.io/properties/PR123/environments")
        .with(body: { data: { type: "environments",
                              attributes: { name: "jsmith-dev", stage: "development" } } }.to_json)
    end
  end

  describe "#delete" do
    before do
      stub_request(:delete, "https://reactor.adobe.io/environments/EN123")
        .to_return(status: 204, body: "")
    end

    it "returns nil on success" do
      result = client.environments.delete("EN123")
      expect(result).to be_nil
    end
  end
end
