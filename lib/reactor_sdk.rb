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
#   Never add a require_relative before the file has content.
#   Never duplicate a require_relative — Ruby will silently ignore the
#   second load but it signals a structural problem.
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
#   properties = client.properties.list_for_company("CO123")
#   library    = client.libraries.find_with_resources("LB123")
#   upstream   = client.libraries.upstream_libraries("LB123", property_id: "PR123")
#   revision   = client.revisions.find("RE123")
#

# ── External gems ────────────────────────────────────────────────
require "faraday"
require "faraday/retry"
require "faraday/net_http"
require "json"
require "uri"

# ── Version ──────────────────────────────────────────────────────
require_relative "reactor_sdk/version"

# ── Errors ───────────────────────────────────────────────────────
# Loaded first — no internal dependencies.
# All other files may raise these error classes.
require_relative "reactor_sdk/error"

# ── Infrastructure ───────────────────────────────────────────────
# Loaded in dependency order — each file depends only on those above it.
require_relative "reactor_sdk/configuration"
require_relative "reactor_sdk/authentication"
require_relative "reactor_sdk/rate_limiter"
require_relative "reactor_sdk/connection"
require_relative "reactor_sdk/paginator"
require_relative "reactor_sdk/response_parser"

# ── Resources ────────────────────────────────────────────────────
# Plain data objects. No dependencies on endpoints.
# base_resource must be loaded before all other resource files.
require_relative "reactor_sdk/resources/base_resource"
require_relative "reactor_sdk/resources/company"
require_relative "reactor_sdk/resources/property"
require_relative "reactor_sdk/resources/environment"
require_relative "reactor_sdk/resources/rule"
require_relative "reactor_sdk/resources/rule_component"
require_relative "reactor_sdk/resources/data_element"
require_relative "reactor_sdk/resources/extension"
require_relative "reactor_sdk/resources/library"
require_relative "reactor_sdk/resources/library_with_resources"
require_relative "reactor_sdk/resources/build"
require_relative "reactor_sdk/resources/revision"
require_relative "reactor_sdk/resources/audit_event"

# ── Endpoints ────────────────────────────────────────────────────
# Depend on resources and infrastructure.
# base_endpoint must be loaded before all other endpoint files.
require_relative "reactor_sdk/endpoints/base_endpoint"
require_relative "reactor_sdk/endpoints/companies"
require_relative "reactor_sdk/endpoints/properties"
require_relative "reactor_sdk/endpoints/environments"
require_relative "reactor_sdk/endpoints/rules"
require_relative "reactor_sdk/endpoints/rule_components"
require_relative "reactor_sdk/endpoints/data_elements"
require_relative "reactor_sdk/endpoints/extensions"
require_relative "reactor_sdk/endpoints/libraries"
require_relative "reactor_sdk/endpoints/builds"
require_relative "reactor_sdk/endpoints/revisions"
require_relative "reactor_sdk/endpoints/audit_events"

# ── Client ───────────────────────────────────────────────────────
# Public API entry point. Depends on everything above.
require_relative "reactor_sdk/client"
