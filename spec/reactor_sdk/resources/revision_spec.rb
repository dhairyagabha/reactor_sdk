# frozen_string_literal: true

##
# @file spec/reactor_sdk/resources/revision_spec.rb
# @description Tests for ReactorSDK::Resources::Revision.
#
#   Covers: attribute mapping, entity_snapshot extraction from included
#   array, entity_id and entity_type from relationships, behaviour when
#   included is absent (list responses), and inspect output.
#

RSpec.describe ReactorSDK::Resources::Revision do
  # ── Helpers ──────────────────────────────────────────────────

  ##
  # Builds a full single-revision API response as Adobe returns it.
  # Mirrors GET /revisions/:id response structure.
  #
  def revision_response(entity_id: "RL123", entity_type: "rules", entity_attributes: {})
    {
      "data" => {
        "id" => "RE123",
        "type" => "revisions",
        "attributes" => {
          "activity_type" => "updated",
          "created_at" => "2024-06-01T14:32:00.000Z"
        },
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
          "attributes" => entity_attributes
        }
      ]
    }
  end

  ##
  # Builds a Revision using the ResponseParser — same path the endpoint uses.
  #
  def parse_revision(response)
    parser = ReactorSDK::ResponseParser.new
    parser.parse(response["data"], ReactorSDK::Resources::Revision, response: response)
  end

  # ── Attribute mapping ────────────────────────────────────────

  describe "attribute mapping" do
    subject(:revision) do
      response = revision_response(
        entity_id: "RL123",
        entity_type: "rules",
        entity_attributes: { "name" => "Order Confirmation", "enabled" => true }
      )
      parse_revision(response)
    end

    it "maps id correctly" do
      expect(revision.id).to eq("RE123")
    end

    it "maps type correctly" do
      expect(revision.type).to eq("revisions")
    end

    it "maps activity_type" do
      expect(revision.activity_type).to eq("updated")
    end

    it "maps created_at" do
      expect(revision.created_at).to eq("2024-06-01T14:32:00.000Z")
    end
  end

  # ── entity_id and entity_type ────────────────────────────────

  describe "#entity_id and #entity_type" do
    context "with a rule revision" do
      it "returns the rule ID" do
        revision = parse_revision(revision_response(entity_id: "RL123", entity_type: "rules"))
        expect(revision.entity_id).to eq("RL123")
      end

      it "returns the rules type" do
        revision = parse_revision(revision_response(entity_id: "RL123", entity_type: "rules"))
        expect(revision.entity_type).to eq("rules")
      end
    end

    context "with a data element revision" do
      it "returns the data element ID" do
        revision = parse_revision(revision_response(entity_id: "DE456", entity_type: "data_elements"))
        expect(revision.entity_id).to eq("DE456")
      end

      it "returns the data_elements type" do
        revision = parse_revision(revision_response(entity_id: "DE456", entity_type: "data_elements"))
        expect(revision.entity_type).to eq("data_elements")
      end
    end

    context "with an extension revision" do
      it "returns the extension ID" do
        revision = parse_revision(revision_response(entity_id: "EX789", entity_type: "extensions"))
        expect(revision.entity_id).to eq("EX789")
      end

      it "returns the extensions type" do
        revision = parse_revision(revision_response(entity_id: "EX789", entity_type: "extensions"))
        expect(revision.entity_type).to eq("extensions")
      end
    end

    context "when relationships are absent" do
      it "returns nil for entity_id" do
        revision = ReactorSDK::Resources::Revision.new(
          id: "RE123", type: "revisions",
          attributes: { "activity_type" => "updated" }
        )
        expect(revision.entity_id).to be_nil
      end

      it "returns nil for entity_type" do
        revision = ReactorSDK::Resources::Revision.new(
          id: "RE123", type: "revisions",
          attributes: { "activity_type" => "updated" }
        )
        expect(revision.entity_type).to be_nil
      end
    end
  end

  # ── entity_snapshot ──────────────────────────────────────────

  describe "#entity_snapshot" do
    context "when the full response includes the entity" do
      it "returns the full attributes of the revisioned resource" do
        response = revision_response(
          entity_id: "RL123",
          entity_type: "rules",
          entity_attributes: {
            "name" => "Order Confirmation",
            "enabled" => true,
            "created_at" => "2024-01-01T00:00:00.000Z"
          }
        )
        revision = parse_revision(response)
        expect(revision.entity_snapshot["name"]).to eq("Order Confirmation")
        expect(revision.entity_snapshot["enabled"]).to be(true)
      end

      it "returns the full settings hash for a rule component snapshot" do
        response = revision_response(
          entity_id: "RC123",
          entity_type: "rule_components",
          entity_attributes: {
            "name" => "Custom Code",
            "settings" => "{\"source\":\"var x = 1;\",\"language\":\"javascript\"}"
          }
        )
        revision = parse_revision(response)
        expect(revision.entity_snapshot["settings"]).to eq(
          "{\"source\":\"var x = 1;\",\"language\":\"javascript\"}"
        )
      end

      it "returns the XDM structure for a Web SDK action snapshot" do
        xdm = { "eventType" => "web.webpagedetails.pageViews" }
        response = revision_response(
          entity_id: "RC456",
          entity_type: "rule_components",
          entity_attributes: {
            "name" => "Send Event",
            "settings" => JSON.generate({ "xdm" => xdm })
          }
        )
        revision = parse_revision(response)
        expect(revision.entity_snapshot["name"]).to eq("Send Event")
      end
    end

    context "when fetched from a list response — no included array" do
      it "returns an empty Hash" do
        revision = ReactorSDK::Resources::Revision.new(
          id: "RE123",
          type: "revisions",
          attributes: { "activity_type" => "updated", "created_at" => "2024-01-01T00:00:00.000Z" }
        )
        expect(revision.entity_snapshot).to eq({})
      end
    end

    context "when included array is present but entity is not found" do
      it "returns an empty Hash" do
        response = {
          "data" => {
            "id" => "RE123",
            "type" => "revisions",
            "attributes" => { "activity_type" => "updated" },
            "relationships" => {
              "entity" => { "data" => { "id" => "RL999", "type" => "rules" } }
            }
          },
          "included" => [
            { "id" => "RL000", "type" => "rules", "attributes" => { "name" => "Other Rule" } }
          ]
        }
        revision = parse_revision(response)
        expect(revision.entity_snapshot).to eq({})
      end
    end
  end

  # ── inspect ──────────────────────────────────────────────────

  describe "#inspect" do
    it "includes id, activity_type, entity_id and entity_type" do
      revision = parse_revision(revision_response(
                                  entity_id: "RL123",
                                  entity_type: "rules"
                                ))
      expect(revision.inspect).to include("RE123")
      expect(revision.inspect).to include("updated")
      expect(revision.inspect).to include("RL123")
      expect(revision.inspect).to include("rules")
    end
  end
end
