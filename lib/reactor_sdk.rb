# frozen_string_literal: true

##
# @file reactor_sdk.rb
# @description Main entry point for the ReactorSDK gem.
#
#   Loads all components in the correct dependency order:
#     1. External gems
#     2. Version
#     3. Errors          — no internal dependencies
#     4. Infrastructure  — configuration, auth, connection, pagination
#     5. Resources       — plain data objects, no endpoint dependencies
#     6. Endpoints       — depend on resources and infrastructure
#     7. Client          — depends on everything above
#
# @usage
#   require "reactor_sdk"
#
#   client = ReactorSDK::Client.new(
#     client_id:     ENV["ADOBE_CLIENT_ID"],
#     client_secret: ENV["ADOBE_CLIENT_SECRET"],
#     org_id:        ENV["ADOBE_IMS_ORG_ID"]
#   )
#

# ── External gems ────────────────────────────────────────────────
require 'faraday'
require 'faraday/retry'
require 'faraday/net_http'
require 'json'
require 'uri'

# ── Version ──────────────────────────────────────────────────────
require_relative 'reactor_sdk/version'

# ── Errors ───────────────────────────────────────────────────────
require_relative 'reactor_sdk/error'

# ── Infrastructure ───────────────────────────────────────────────
require_relative 'reactor_sdk/configuration'
require_relative 'reactor_sdk/authentication'
require_relative 'reactor_sdk/rate_limiter'
require_relative 'reactor_sdk/connection'
require_relative 'reactor_sdk/paginator'
require_relative 'reactor_sdk/response_parser'

# ── Resources ────────────────────────────────────────────────────
require_relative 'reactor_sdk/resources/base_resource'
require_relative 'reactor_sdk/resources/company'
require_relative 'reactor_sdk/resources/property'
require_relative 'reactor_sdk/resources/environment'
require_relative 'reactor_sdk/resources/host'
require_relative 'reactor_sdk/resources/rule'
require_relative 'reactor_sdk/resources/rule_component'
require_relative 'reactor_sdk/resources/data_element'
require_relative 'reactor_sdk/resources/extension'
require_relative 'reactor_sdk/resources/extension_package'
require_relative 'reactor_sdk/resources/library'
require_relative 'reactor_sdk/resources/library_with_resources'
require_relative 'reactor_sdk/resources/build'
require_relative 'reactor_sdk/resources/revision'
require_relative 'reactor_sdk/resources/audit_event'
require_relative 'reactor_sdk/resources/note'

# ── Endpoints ────────────────────────────────────────────────────
require_relative 'reactor_sdk/endpoints/base_endpoint'
require_relative 'reactor_sdk/endpoints/companies'
require_relative 'reactor_sdk/endpoints/properties'
require_relative 'reactor_sdk/endpoints/environments'
require_relative 'reactor_sdk/endpoints/hosts'
require_relative 'reactor_sdk/endpoints/rules'
require_relative 'reactor_sdk/endpoints/rule_components'
require_relative 'reactor_sdk/endpoints/data_elements'
require_relative 'reactor_sdk/endpoints/extensions'
require_relative 'reactor_sdk/endpoints/libraries'
require_relative 'reactor_sdk/endpoints/builds'
require_relative 'reactor_sdk/endpoints/revisions'
require_relative 'reactor_sdk/endpoints/audit_events'

# ── Client ───────────────────────────────────────────────────────
require_relative 'reactor_sdk/client'
