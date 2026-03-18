# frozen_string_literal: true

##
# @file spec/reactor_sdk/endpoints/revisions_spec.rb
# @description Tests for ReactorSDK::Endpoints::Revisions.
#
#   Covers: find with full entity snapshot, list_for_rule,
#   list_for_data_element, list_for_extension, and error handling.
#

RSpec.describe ReactorSDK::Endpoints::Revisions do
  subject(:client) { test_client }

  let(:revision_attributes) do
    {
      "activity_type" => "updated",
      "created_at" => "2024-06-01T14:32:00.000Z"
    }
  end

  let(:rule_attributes) do
    {
      "name" => "Order Confirmation",
      "enabled" => true
    }
  end

  ##
  # Builds a full single-revision response with included entity snapshot.
  #
  def full_revision_response(entity_id: "RL123", entity_type: "rules", entity_attrs: {})
    {
      "data" => {
        "id" => "RE123",
        "type" => "revisions",
        "attributes" => revision_attributes,
        "relationships" => {
          "entity" => {
            "data" => { "id" => entity_id, "type" => entity_type }
          }
        }
      },
      "included" => [
        {
          "id" => entity_id,
          "type" => entity_type,
          "attributes" => entity_attrs
        }
      ]
    }.to_json
  end

  ##
  # Builds a list response of revisions — no included array.
  #
  def revision_list_response(count: 2)
    items = count.times.map do |i|
      {
        "id" => "RE#{i + 1}",
        "type" => "revisions",
        "attributes" => revision_attributes.merge("activity_type" => i.zero? ? "updated" : "created"),
        "relationships" => {}
      }
    end
    { "data" => items, "links" => { "next" => nil } }.to_json
  end

  # ── find ─────────────────────────────────────────────────────

  describe "#find" do
    context "with a rule revision" do
      before do
        stub_request(:get, "https://reactor.adobe.io/revisions/RE123")
          .to_return(
            status: 200,
            body: full_revision_response(
              entity_id: "RL123",
              entity_type: "rules",
              entity_attrs: rule_attributes
            ),
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "returns a Revision resource" do
        result = client.revisions.find("RE123")
        expect(result).to be_a(ReactorSDK::Resources::Revision)
      end

      it "maps the revision id correctly" do
        result = client.revisions.find("RE123")
        expect(result.id).to eq("RE123")
      end

      it "maps activity_type" do
        result = client.revisions.find("RE123")
        expect(result.activity_type).to eq("updated")
      end

      it "maps entity_id from relationships" do
        result = client.revisions.find("RE123")
        expect(result.entity_id).to eq("RL123")
      end

      it "maps entity_type from relationships" do
        result = client.revisions.find("RE123")
        expect(result.entity_type).to eq("rules")
      end

      it "populates entity_snapshot from the included array" do
        result = client.revisions.find("RE123")
        expect(result.entity_snapshot["name"]).to eq("Order Confirmation")
        expect(result.entity_snapshot["enabled"]).to be(true)
      end
    end

    context "with a data element revision" do
      before do
        stub_request(:get, "https://reactor.adobe.io/revisions/RE456")
          .to_return(
            status: 200,
            body: full_revision_response(
              entity_id: "DE456",
              entity_type: "data_elements",
              entity_attrs: {
                "name" => "Page Name",
                "settings" => "{\"source\":\"return digitalData.page.name;\"}"
              }
            ),
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "returns a Revision resource" do
        result = client.revisions.find("RE456")
        expect(result).to be_a(ReactorSDK::Resources::Revision)
      end

      it "populates entity_snapshot with data element attributes" do
        result = client.revisions.find("RE456")
        expect(result.entity_snapshot["name"]).to eq("Page Name")
        expect(result.entity_snapshot["settings"]).to include("source")
      end

      it "maps entity_type as data_elements" do
        result = client.revisions.find("RE456")
        expect(result.entity_type).to eq("data_elements")
      end
    end

    context "with an extension revision" do
      before do
        stub_request(:get, "https://reactor.adobe.io/revisions/RE789")
          .to_return(
            status: 200,
            body: full_revision_response(
              entity_id: "EX789",
              entity_type: "extensions",
              entity_attrs: { "name" => "Adobe Analytics",
                              "delegate_descriptor_id" => "adobe-analytics::extensionName::2.1.0" }
            ),
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "populates entity_snapshot with extension attributes" do
        result = client.revisions.find("RE789")
        expect(result.entity_snapshot["name"]).to eq("Adobe Analytics")
        expect(result.entity_type).to eq("extensions")
      end
    end

    context "when the revision does not exist" do
      before do
        stub_request(:get, "https://reactor.adobe.io/revisions/RE_INVALID")
          .to_return(status: 404, body: { errors: [] }.to_json)
      end

      it "raises ResourceNotFoundError" do
        expect do
          client.revisions.find("RE_INVALID")
        end.to raise_error(ReactorSDK::ResourceNotFoundError)
      end
    end
  end

  # ── list_for_rule ─────────────────────────────────────────────

  describe "#list_for_rule" do
    before do
      stub_request(:get, "https://reactor.adobe.io/rules/RL123/revisions?page%5Bsize%5D=100")
        .to_return(
          status: 200,
          body: revision_list_response(count: 2),
          headers: { "Content-Type" => "application/json" }
        )
    end

    it "returns an array of Revision resources" do
      result = client.revisions.list_for_rule("RL123")
      expect(result).to all(be_a(ReactorSDK::Resources::Revision))
    end

    it "returns the correct number of revisions" do
      result = client.revisions.list_for_rule("RL123")
      expect(result.length).to eq(2)
    end

    it "returns revision metadata without entity snapshots" do
      result = client.revisions.list_for_rule("RL123")
      expect(result.first.entity_snapshot).to eq({})
    end

    it "maps activity_type on each revision" do
      result = client.revisions.list_for_rule("RL123")
      expect(result.first.activity_type).to eq("updated")
      expect(result.last.activity_type).to eq("created")
    end
  end

  # ── list_for_data_element ─────────────────────────────────────

  describe "#list_for_data_element" do
    before do
      stub_request(:get, "https://reactor.adobe.io/data_elements/DE123/revisions?page%5Bsize%5D=100")
        .to_return(
          status: 200,
          body: revision_list_response(count: 1),
          headers: { "Content-Type" => "application/json" }
        )
    end

    it "returns an array of Revision resources" do
      result = client.revisions.list_for_data_element("DE123")
      expect(result).to all(be_a(ReactorSDK::Resources::Revision))
    end

    it "returns the correct number of revisions" do
      result = client.revisions.list_for_data_element("DE123")
      expect(result.length).to eq(1)
    end
  end

  # ── list_for_extension ────────────────────────────────────────

  describe "#list_for_extension" do
    before do
      stub_request(:get, "https://reactor.adobe.io/extensions/EX123/revisions?page%5Bsize%5D=100")
        .to_return(
          status: 200,
          body: revision_list_response(count: 3),
          headers: { "Content-Type" => "application/json" }
        )
    end

    it "returns an array of Revision resources" do
      result = client.revisions.list_for_extension("EX123")
      expect(result).to all(be_a(ReactorSDK::Resources::Revision))
    end

    it "returns the correct number of revisions" do
      result = client.revisions.list_for_extension("EX123")
      expect(result.length).to eq(3)
    end
  end
end
