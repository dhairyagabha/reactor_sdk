# frozen_string_literal: true

##
# @file spec/reactor_sdk/resources/data_element_spec.rb
# @description Tests for ReactorSDK::Resources::DataElement.
#
#   Covers: attribute mapping, parsed_settings across all known
#   input types — same coverage as rule_component_spec since both
#   resources share the same parsed_settings implementation.
#

RSpec.describe ReactorSDK::Resources::DataElement do
  ##
  # Builds a DataElement with the given attributes.
  #
  def build_element(attributes = {})
    described_class.new(
      id: "DE123",
      type: "data_elements",
      attributes: attributes
    )
  end

  # ── Attribute mapping ─────────────────────────────────────────

  describe "attribute mapping" do
    subject(:element) do
      build_element(
        "name" => "Page Name",
        "delegate_descriptor_id" => "core::dataElements::custom-code",
        "enabled" => true,
        "clean_text" => false,
        "force_lower_case" => false,
        "default_value" => "unknown",
        "storage_duration" => "pageview",
        "settings" => "{}",
        "created_at" => "2024-01-01T00:00:00.000Z",
        "updated_at" => "2024-01-02T00:00:00.000Z"
      )
    end

    it { expect(element.name).to eq("Page Name") }
    it { expect(element.delegate_descriptor_id).to eq("core::dataElements::custom-code") }
    it { expect(element.enabled?).to be(true) }
    it { expect(element.clean_text?).to be(false) }
    it { expect(element.force_lower_case?).to be(false) }
    it { expect(element.default_value).to eq("unknown") }
    it { expect(element.storage_duration).to eq("pageview") }
    it { expect(element.created_at).to eq("2024-01-01T00:00:00.000Z") }
    it { expect(element.updated_at).to eq("2024-01-02T00:00:00.000Z") }
  end

  # ── parsed_settings ───────────────────────────────────────────

  describe "#parsed_settings" do
    context "with Core custom code — JavaScript" do
      it "parses the JSON-encoded string into a Hash" do
        element = build_element(
          "settings" => "{\"source\":\"return digitalData.page.pageInfo.pageName;\",\"language\":\"javascript\"}"
        )
        expect(element.parsed_settings).to eq(
          "source" => "return digitalData.page.pageInfo.pageName;",
          "language" => "javascript"
        )
      end
    end

    context "with a structured settings object" do
      it "parses the full settings structure" do
        settings = { "path" => "page.name", "fallback" => "unknown" }
        element  = build_element("settings" => JSON.generate(settings))
        expect(element.parsed_settings["path"]).to eq("page.name")
        expect(element.parsed_settings["fallback"]).to eq("unknown")
      end
    end

    context "when settings is already a Hash" do
      it "returns it as-is without re-parsing" do
        hash    = { "path" => "window.location.href" }
        element = build_element("settings" => hash)
        expect(element.parsed_settings).to eq(hash)
      end
    end

    context "when settings is nil" do
      it "returns an empty Hash" do
        element = build_element("settings" => nil)
        expect(element.parsed_settings).to eq({})
      end
    end

    context "when settings is a blank string" do
      it "returns an empty Hash" do
        element = build_element("settings" => "")
        expect(element.parsed_settings).to eq({})
      end
    end

    context "when settings is unparseable JSON" do
      it "returns an empty Hash without raising" do
        element = build_element("settings" => "{not valid{{")
        expect { element.parsed_settings }.not_to raise_error
        expect(element.parsed_settings).to eq({})
      end

      it "preserves the raw value on the settings attribute" do
        element = build_element("settings" => "{not valid{{")
        element.parsed_settings
        expect(element.settings).to eq("{not valid{{")
      end
    end

    context "with a large custom code block" do
      it "parses without truncation" do
        large_code = "return '#{"x" * 100}';\n" * 200
        element    = build_element(
          "settings" => JSON.generate({ "source" => large_code, "language" => "javascript" })
        )
        expect(element.parsed_settings["source"].length).to eq(large_code.length)
      end
    end

    context "raw settings is never modified" do
      it "preserves the original JSON string after calling parsed_settings" do
        raw     = "{\"source\":\"return 'hello';\"}"
        element = build_element("settings" => raw)
        element.parsed_settings
        expect(element.settings).to eq(raw)
      end
    end
  end

  # ── inspect ───────────────────────────────────────────────────

  describe "#inspect" do
    it "includes id, name and delegate_descriptor_id" do
      element = build_element(
        "name" => "Page Name",
        "delegate_descriptor_id" => "core::dataElements::custom-code"
      )
      expect(element.inspect).to include("DE123")
      expect(element.inspect).to include("Page Name")
      expect(element.inspect).to include("core::dataElements::custom-code")
    end
  end
end
