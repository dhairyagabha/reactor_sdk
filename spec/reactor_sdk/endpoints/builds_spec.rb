# frozen_string_literal: true

##
# @file spec/reactor_sdk/endpoints/builds_spec.rb
# @description Tests for ReactorSDK::Endpoints::Builds.
#
#   Covers: find, list_for_library, and Build resource
#   helper methods (succeeded?, pending?, failed?).
#   Build polling is critical for LaunchGuard — after triggering
#   a build we poll until status is succeeded or failed.
#

RSpec.describe ReactorSDK::Endpoints::Builds do
  subject(:client) { test_client }

  let(:succeeded_build_attributes) do
    {
      "status" => "succeeded",
      "created_at" => "2024-01-01T00:00:00.000Z",
      "updated_at" => "2024-01-01T00:00:00.000Z"
    }
  end

  let(:pending_build_attributes) do
    {
      "status" => "processing",
      "created_at" => "2024-01-01T00:00:00.000Z",
      "updated_at" => "2024-01-01T00:00:00.000Z"
    }
  end

  let(:failed_build_attributes) do
    {
      "status" => "failed",
      "created_at" => "2024-01-01T00:00:00.000Z",
      "updated_at" => "2024-01-01T00:00:00.000Z"
    }
  end

  describe "#find" do
    context "when the build succeeded" do
      before do
        stub_request(:get, "https://reactor.adobe.io/builds/BL123")
          .to_return(
            status: 200,
            body: jsonapi_response(type: "builds", id: "BL123", attributes: succeeded_build_attributes).to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "returns a Build resource" do
        result = client.builds.find("BL123")
        expect(result).to be_a(ReactorSDK::Resources::Build)
      end

      it "maps the id correctly" do
        result = client.builds.find("BL123")
        expect(result.id).to eq("BL123")
      end

      it "reports succeeded? as true" do
        result = client.builds.find("BL123")
        expect(result.succeeded?).to be(true)
        expect(result.pending?).to be(false)
        expect(result.failed?).to be(false)
      end
    end

    context "when the build is processing" do
      before do
        stub_request(:get, "https://reactor.adobe.io/builds/BL123")
          .to_return(
            status: 200,
            body: jsonapi_response(type: "builds", id: "BL123", attributes: pending_build_attributes).to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "reports pending? as true" do
        result = client.builds.find("BL123")
        expect(result.pending?).to be(true)
        expect(result.succeeded?).to be(false)
        expect(result.failed?).to be(false)
      end
    end

    context "when the build failed" do
      before do
        stub_request(:get, "https://reactor.adobe.io/builds/BL123")
          .to_return(
            status: 200,
            body: jsonapi_response(type: "builds", id: "BL123", attributes: failed_build_attributes).to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "reports failed? as true" do
        result = client.builds.find("BL123")
        expect(result.failed?).to be(true)
        expect(result.succeeded?).to be(false)
        expect(result.pending?).to be(false)
      end
    end

    context "when the build does not exist" do
      before do
        stub_request(:get, "https://reactor.adobe.io/builds/BL_INVALID")
          .to_return(status: 404, body: { errors: [] }.to_json)
      end

      it "raises ResourceNotFoundError" do
        expect do
          client.builds.find("BL_INVALID")
        end.to raise_error(ReactorSDK::ResourceNotFoundError)
      end
    end
  end

  describe "#list_for_library" do
    before do
      stub_request(:get, "https://reactor.adobe.io/libraries/LB123/builds?page%5Bsize%5D=100")
        .to_return(
          status: 200,
          body: jsonapi_list_response(
            type: "builds",
            items: [
              { id: "BL123", attributes: succeeded_build_attributes },
              { id: "BL456", attributes: failed_build_attributes }
            ]
          ).to_json,
          headers: { "Content-Type" => "application/json" }
        )
    end

    it "returns an array of Build resources" do
      result = client.builds.list_for_library("LB123")
      expect(result).to all(be_a(ReactorSDK::Resources::Build))
    end

    it "returns the correct number of builds" do
      result = client.builds.list_for_library("LB123")
      expect(result.length).to eq(2)
    end

    it "maps statuses correctly" do
      result = client.builds.list_for_library("LB123")
      expect(result.first.succeeded?).to be(true)
      expect(result.last.failed?).to be(true)
    end
  end
end
