# frozen_string_literal: true

module ReactorSDK
  module Resources
    class SearchResults
      include Enumerable

      attr_reader :results, :meta

      def initialize(results:, meta: {})
        @results = results
        @meta = meta
      end

      def each(&)
        results.each(&)
      end

      def total_hits
        meta.fetch('total_hits', results.length)
      end

      def inspect
        "#<ReactorSDK::Resources::SearchResults total_hits=#{total_hits} size=#{results.length}>"
      end
    end
  end
end
