# frozen_string_literal: true

##
# @file spec/reactor_sdk/paginator_spec.rb
# @description Tests for ReactorSDK::Paginator.
#
#   Covers: single page response, multi-page cursor following,
#   empty results, block yielding, extra params forwarding,
#   and error propagation from the connection.
#

RSpec.describe ReactorSDK::Paginator do
  subject(:paginator) { described_class.new(connection) }

  let(:connection) { instance_double(ReactorSDK::Connection) }

  # ── Helpers ────────────────────────────────────────────────────

  ##
  # Builds a single-page JSON:API list response with no next cursor.
  #
  def page(items, next_url: nil)
    {
      "data" => items,
      "links" => { "next" => next_url }
    }
  end

  ##
  # Builds a minimal JSON:API resource hash.
  #
  def resource(id, type: "rules", name: "Rule #{id}")
    {
      "id" => id,
      "type" => type,
      "attributes" => { "name" => name }
    }
  end

  # ── Single page ─────────────────────────────────────────────────

  describe "#all" do
    context "with a single page of results" do
      before do
        allow(connection).to receive(:get)
          .with("/properties/PR123/rules?page%5Bsize%5D=100")
          .and_return(page([resource("RL1"), resource("RL2")]))
      end

      it "returns all records from the single page" do
        result = paginator.all("/properties/PR123/rules")
        expect(result.length).to eq(2)
      end

      it "returns the raw JSON:API hashes" do
        result = paginator.all("/properties/PR123/rules")
        expect(result.first["id"]).to eq("RL1")
        expect(result.last["id"]).to eq("RL2")
      end

      it "makes exactly one HTTP request" do
        paginator.all("/properties/PR123/rules")
        expect(connection).to have_received(:get).once
      end
    end

    # ── Multiple pages ───────────────────────────────────────────

    context "with multiple pages of results" do
      before do
        # Page 1 — has a next cursor
        allow(connection).to receive(:get)
          .with("/properties/PR123/rules?page%5Bsize%5D=100")
          .and_return(page(
                        [resource("RL1"), resource("RL2")],
                        next_url: "/properties/PR123/rules?page%5Bsize%5D=100&page%5Bcursor%5D=abc"
                      ))

        # Page 2 — has a next cursor
        allow(connection).to receive(:get)
          .with("/properties/PR123/rules?page%5Bsize%5D=100&page%5Bcursor%5D=abc")
          .and_return(page(
                        [resource("RL3"), resource("RL4")],
                        next_url: "/properties/PR123/rules?page%5Bsize%5D=100&page%5Bcursor%5D=def"
                      ))

        # Page 3 — no next cursor
        allow(connection).to receive(:get)
          .with("/properties/PR123/rules?page%5Bsize%5D=100&page%5Bcursor%5D=def")
          .and_return(page([resource("RL5")]))
      end

      it "follows cursors and returns all records across all pages" do
        result = paginator.all("/properties/PR123/rules")
        expect(result.length).to eq(5)
      end

      it "returns records in page order" do
        result = paginator.all("/properties/PR123/rules")
        expect(result.map { |r| r["id"] }).to eq(%w[RL1 RL2 RL3 RL4 RL5])
      end

      it "makes exactly three HTTP requests" do
        paginator.all("/properties/PR123/rules")
        expect(connection).to have_received(:get).exactly(3).times
      end
    end

    # ── Empty results ────────────────────────────────────────────

    context "with an empty result set" do
      before do
        allow(connection).to receive(:get)
          .with("/properties/PR123/rules?page%5Bsize%5D=100")
          .and_return(page([]))
      end

      it "returns an empty array" do
        result = paginator.all("/properties/PR123/rules")
        expect(result).to eq([])
      end

      it "makes exactly one HTTP request" do
        paginator.all("/properties/PR123/rules")
        expect(connection).to have_received(:get).once
      end
    end

    # ── Nil data field ───────────────────────────────────────────

    context "when the response has no data field" do
      before do
        allow(connection).to receive(:get)
          .with("/properties/PR123/rules?page%5Bsize%5D=100")
          .and_return({ "links" => { "next" => nil } })
      end

      it "returns an empty array without raising" do
        result = paginator.all("/properties/PR123/rules")
        expect(result).to eq([])
      end
    end

    # ── Block yielding ───────────────────────────────────────────

    context "when a block is given" do
      before do
        allow(connection).to receive(:get)
          .with("/properties/PR123/rules?page%5Bsize%5D=100")
          .and_return(page([resource("RL1"), resource("RL2")]))
      end

      it "yields each record as it is fetched" do
        yielded = []
        paginator.all("/properties/PR123/rules") { |r| yielded << r["id"] }
        expect(yielded).to eq(%w[RL1 RL2])
      end

      it "still returns the full array" do
        result = paginator.all("/properties/PR123/rules") { |_r| }
        expect(result.length).to eq(2)
      end
    end

    context "when a block is given across multiple pages" do
      before do
        allow(connection).to receive(:get)
          .with("/properties/PR123/rules?page%5Bsize%5D=100")
          .and_return(page(
                        [resource("RL1")],
                        next_url: "/properties/PR123/rules?page%5Bsize%5D=100&page%5Bcursor%5D=abc"
                      ))
        allow(connection).to receive(:get)
          .with("/properties/PR123/rules?page%5Bsize%5D=100&page%5Bcursor%5D=abc")
          .and_return(page([resource("RL2")]))
      end

      it "yields records from every page in order" do
        yielded = []
        paginator.all("/properties/PR123/rules") { |r| yielded << r["id"] }
        expect(yielded).to eq(%w[RL1 RL2])
      end
    end

    # ── Extra params ─────────────────────────────────────────────

    context "when extra params are provided" do
      it "merges extra params into the initial request URL" do
        # Allow any URL that contains both required params — order is not guaranteed
        allow(connection).to receive(:get)
          .with(a_string_including("page%5Bsize%5D=100"))
          .and_return(page([resource("AE1", type: "audit_events")]))

        result = paginator.all(
          "/properties/PR123/audit_events",
          params: { "filter[created_at]" => "GT 2024-01-01" }
        )

        expect(result.length).to eq(1)
        expect(connection).to have_received(:get)
          .with(a_string_including("filter%5Bcreated_at%5D"))
        expect(connection).to have_received(:get)
          .with(a_string_including("page%5Bsize%5D=100"))
      end
    end

    # ── Error propagation ────────────────────────────────────────

    context "when the connection raises an error" do
      before do
        allow(connection).to receive(:get)
          .and_raise(ReactorSDK::ResourceNotFoundError.new("not found", status: 404))
      end

      it "propagates the error to the caller" do
        expect do
          paginator.all("/properties/PR_INVALID/rules")
        end.to raise_error(ReactorSDK::ResourceNotFoundError)
      end
    end

    context "when the connection raises a rate limit error" do
      before do
        allow(connection).to receive(:get)
          .and_raise(ReactorSDK::RateLimitError.new("rate limited", retry_after: 30))
      end

      it "propagates the RateLimitError to the caller" do
        expect do
          paginator.all("/properties/PR123/rules")
        end.to raise_error(ReactorSDK::RateLimitError)
      end
    end
  end

  # ── URL builder ──────────────────────────────────────────────

  describe "#build_initial_url (private)" do
    it "appends default page size to a clean path" do
      url = paginator.send(:build_initial_url, "/properties/PR123/rules", {})
      expect(url).to eq("/properties/PR123/rules?page%5Bsize%5D=100")
    end

    it "includes both page size and caller params in the URL" do
      url = paginator.send(
        :build_initial_url,
        "/properties/PR123/audit_events",
        { "filter[created_at]" => "GT 2024-01-01" }
      )
      expect(url).to include("page%5Bsize%5D=100")
      expect(url).to include("filter%5Bcreated_at%5D=GT+2024-01-01")
    end

    it "handles symbol keys in params by converting to strings" do
      url = paginator.send(
        :build_initial_url,
        "/properties/PR123/rules",
        { page_size: 50 }
      )
      expect(url).to include("page%5Bsize%5D=100")
    end
  end

  # ── Constants ────────────────────────────────────────────────

  describe "constants" do
    it "has a DEFAULT_PAGE_SIZE of 100" do
      expect(described_class::DEFAULT_PAGE_SIZE).to eq(100)
    end
  end
end
