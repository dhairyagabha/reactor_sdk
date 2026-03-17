# frozen_string_literal: true

##
# @file spec/reactor_sdk/endpoints/libraries_spec.rb
# @description Tests for ReactorSDK::Endpoints::Libraries.
#
#   Covers: list, find, create, add_rules, add_data_elements,
#   add_extensions, assign_environment, transition, build,
#   and error handling.
#

RSpec.describe ReactorSDK::Endpoints::Libraries do
  subject(:client) { test_client }

  let(:library_attributes) do
    {
      "name"         => "Release 1.0",
      "state"        => "development",
      "published"    => false,
      "created_at"   => "2024-01-01T00:00:00.000Z",
      "updated_at"   => "2024-01-01T00:00:00.000Z",
      "published_at" => nil
    }
  end

  let(:build_attributes) do
    {
      "status"     => "succeeded",
      "created_at" => "2024-01-01T00:00:00.000Z",
      "updated_at" => "2024-01-01T00:00:00.000Z"
    }
  end

  let(:single_response) do
    jsonapi_response(
      type:       "libraries",
      id:         "LB123",
      attributes: library_attributes
    ).to_json
  end

  let(:list_response) do
    jsonapi_list_response(
      type:  "libraries",
      items: [
        { id: "LB123", attributes: library_attributes },
        { id: "LB456", attributes: library_attributes.merge("name" => "Release 2.0") }
      ]
    ).to_json
  end

  let(:build_response) do
    jsonapi_response(
      type:       "builds",
      id:         "BL123",
      attributes: build_attributes
    ).to_json
  end

  describe "#list_for_property" do
    before do
      stub_request(:get, "https://reactor.adobe.io/properties/PR123/libraries?page%5Bsize%5D=100")
        .to_return(status: 200, body: list_response, headers: { "Content-Type" => "application/json" })
    end

    it "returns an array of Library resources" do
      result = client.libraries.list_for_property("PR123")
      expect(result).to all(be_a(ReactorSDK::Resources::Library))
    end

    it "returns the correct number of libraries" do
      result = client.libraries.list_for_property("PR123")
      expect(result.length).to eq(2)
    end

    it "maps attributes to Ruby methods" do
      result = client.libraries.list_for_property("PR123")
      expect(result.first.name).to eq("Release 1.0")
      expect(result.first.state).to eq("development")
    end

    it "returns the correct ids" do
      result = client.libraries.list_for_property("PR123")
      expect(result.map(&:id)).to eq(["LB123", "LB456"])
    end
  end

  describe "#find" do
    before do
      stub_request(:get, "https://reactor.adobe.io/libraries/LB123")
        .to_return(status: 200, body: single_response, headers: { "Content-Type" => "application/json" })
    end

    it "returns a Library resource" do
      result = client.libraries.find("LB123")
      expect(result).to be_a(ReactorSDK::Resources::Library)
    end

    it "maps the id correctly" do
      result = client.libraries.find("LB123")
      expect(result.id).to eq("LB123")
    end

    it "maps attributes to Ruby methods" do
      result = client.libraries.find("LB123")
      expect(result.name).to eq("Release 1.0")
      expect(result.state).to eq("development")
      expect(result.buildable?).to be(true)
      expect(result.published?).to be(false)
    end

    context "when the library does not exist" do
      before do
        stub_request(:get, "https://reactor.adobe.io/libraries/LB_INVALID")
          .to_return(status: 404, body: { errors: [] }.to_json)
      end

      it "raises ResourceNotFoundError" do
        expect {
          client.libraries.find("LB_INVALID")
        }.to raise_error(ReactorSDK::ResourceNotFoundError)
      end
    end
  end

  describe "#create" do
    before do
      stub_request(:post, "https://reactor.adobe.io/properties/PR123/libraries")
        .to_return(status: 201, body: single_response, headers: { "Content-Type" => "application/json" })
    end

    it "returns a Library resource" do
      result = client.libraries.create(property_id: "PR123", name: "Release 1.0")
      expect(result).to be_a(ReactorSDK::Resources::Library)
    end

    it "maps attributes on the returned resource" do
      result = client.libraries.create(property_id: "PR123", name: "Release 1.0")
      expect(result.name).to eq("Release 1.0")
      expect(result.state).to eq("development")
    end
  end

  describe "#add_rules" do
    before do
      stub_request(:post, "https://reactor.adobe.io/libraries/LB123/relationships/rules")
        .to_return(status: 201, body: "")
    end

    it "returns nil on success" do
      result = client.libraries.add_rules("LB123", ["RL123", "RL456"])
      expect(result).to be_nil
    end

    it "sends the correct relationship payload" do
      client.libraries.add_rules("LB123", ["RL123", "RL456"])
      expect(WebMock).to have_requested(:post, "https://reactor.adobe.io/libraries/LB123/relationships/rules")
        .with(body: { data: [{ id: "RL123", type: "rules" }, { id: "RL456", type: "rules" }] }.to_json)
    end
  end

  describe "#add_data_elements" do
    before do
      stub_request(:post, "https://reactor.adobe.io/libraries/LB123/relationships/data_elements")
        .to_return(status: 201, body: "")
    end

    it "returns nil on success" do
      result = client.libraries.add_data_elements("LB123", ["DE123"])
      expect(result).to be_nil
    end

    it "sends the correct relationship payload" do
      client.libraries.add_data_elements("LB123", ["DE123"])
      expect(WebMock).to have_requested(:post, "https://reactor.adobe.io/libraries/LB123/relationships/data_elements")
        .with(body: { data: [{ id: "DE123", type: "data_elements" }] }.to_json)
    end
  end

  describe "#add_extensions" do
    before do
      stub_request(:post, "https://reactor.adobe.io/libraries/LB123/relationships/extensions")
        .to_return(status: 201, body: "")
    end

    it "returns nil on success" do
      result = client.libraries.add_extensions("LB123", ["EX123"])
      expect(result).to be_nil
    end

    it "sends the correct relationship payload" do
      client.libraries.add_extensions("LB123", ["EX123"])
      expect(WebMock).to have_requested(:post, "https://reactor.adobe.io/libraries/LB123/relationships/extensions")
        .with(body: { data: [{ id: "EX123", type: "extensions" }] }.to_json)
    end
  end

  describe "#assign_environment" do
    before do
      stub_request(:patch, "https://reactor.adobe.io/libraries/LB123/relationships/environment")
        .to_return(status: 204, body: "")
    end

    it "returns nil on success" do
      result = client.libraries.assign_environment("LB123", "EN123")
      expect(result).to be_nil
    end

    it "sends the correct relationship payload" do
      client.libraries.assign_environment("LB123", "EN123")
      expect(WebMock).to have_requested(:patch, "https://reactor.adobe.io/libraries/LB123/relationships/environment")
        .with(body: { data: { id: "EN123", type: "environments" } }.to_json)
    end
  end

  describe "#transition" do
    before do
      stub_request(:patch, "https://reactor.adobe.io/libraries/LB123")
        .to_return(
          status: 200,
          body:   jsonapi_response(
            type:       "libraries",
            id:         "LB123",
            attributes: library_attributes.merge("state" => "submitted")
          ).to_json,
          headers: { "Content-Type" => "application/json" }
        )
    end

    it "returns a Library resource" do
      result = client.libraries.transition("LB123", state: "submitted")
      expect(result).to be_a(ReactorSDK::Resources::Library)
    end

    it "reflects the new state" do
      result = client.libraries.transition("LB123", state: "submitted")
      expect(result.state).to eq("submitted")
    end
  end

  describe "#build" do
    before do
      stub_request(:post, "https://reactor.adobe.io/libraries/LB123/builds")
        .to_return(status: 201, body: build_response, headers: { "Content-Type" => "application/json" })
    end

    it "returns a Build resource" do
      result = client.libraries.build("LB123")
      expect(result).to be_a(ReactorSDK::Resources::Build)
    end

    it "maps build attributes correctly" do
      result = client.libraries.build("LB123")
      expect(result.status).to eq("succeeded")
      expect(result.succeeded?).to be(true)
    end
  end
end
