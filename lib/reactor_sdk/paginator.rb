# frozen_string_literal: true

##
# @file paginator.rb
# @description Handles cursor-based pagination for Reactor API list endpoints.
#
#   The Reactor API paginates all list responses using JSON:API cursor links.
#   Each response includes a `links` object with a `next` URL. This class
#   follows that cursor until it is absent, collecting all records into a
#   single flat array.
#
#   IMPORTANT: Always use this paginator for list endpoints.
#   Never make a single GET to a list endpoint — Adobe defaults to 25 records
#   per page and silently truncates results without any warning or error.
#   A property with 100 rules will return only 25 without pagination.
#
# @domain Infrastructure
# @depends ReactorSDK::Connection
#
# @example Fetch all rules for a property
#   paginator = ReactorSDK::Paginator.new(connection)
#   records = paginator.all("/properties/PR123/rules")
#   # => Array of all rule hashes across every page
#

module ReactorSDK
  class Paginator
    # Number of records to request per page.
    # Adobe's maximum is 100 — always request the maximum to minimise
    # the number of API calls made.
    DEFAULT_PAGE_SIZE = 100

    ##
    # @param connection [ReactorSDK::Connection] Authenticated HTTP connection
    #
    def initialize(connection)
      @connection = connection
    end

    ##
    # Fetches every record from a paginated list endpoint.
    #
    # Follows the `links.next` cursor in each response until it is absent,
    # then returns all collected records as a single flat array.
    #
    # An optional block can be provided to process each record as it arrives
    # rather than waiting for all pages to complete — useful for large datasets.
    #
    # @param path   [String] Relative API path (e.g. "/properties/PR123/rules")
    # @param params [Hash]   Additional query parameters to merge into the request
    # @yield  [Hash] Each raw JSON:API record hash as it is fetched (optional)
    # @return [Array<Hash>] All records across every page as a flat array
    # @raise  [ReactorSDK::Error] on any non-2xx response during pagination
    #
    def all(path, params: {})
      records  = []
      next_url = build_initial_url(path, params)

      while next_url
        response = @connection.get(next_url)
        data     = Array(response&.fetch('data', []))

        data.each do |record|
          yield record if block_given?
          records << record
        end

        next_url = response&.dig('links', 'next')
      end

      records
    end

    private

    ##
    # Builds the initial request URL with the page size parameter appended.
    # Merges any caller-supplied params so they are included on every page.
    #
    # @param path   [String] Base API path without query string
    # @param params [Hash]   Caller-supplied query parameters
    # @return [String] Full path with query string
    #
    def build_initial_url(path, params)
      query_params = { 'page[size]' => DEFAULT_PAGE_SIZE }
                     .merge(params.transform_keys(&:to_s))

      query_string = URI.encode_www_form(query_params)
      "#{path}?#{query_string}"
    end
  end
end
