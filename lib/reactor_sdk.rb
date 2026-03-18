# frozen_string_literal: true

##
# @file reactor_sdk.rb
# @description Main entry point for the ReactorSDK gem.
#              Loads all components in the correct dependency order.
#              Each require_relative line is added here as each file
#              is implemented — do not add a require before the file
#              has content or the load will silently succeed with an
#              empty module.
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

# External gems
require "faraday"
require "faraday/retry"
require "faraday/net_http"
require "json"
require "uri"

# Version
require_relative "reactor_sdk/version"

# Errors — no internal dependencies, always loaded first
require_relative "reactor_sdk/error"

# Infrastructure — loaded in dependency order
require_relative "reactor_sdk/configuration"
require_relative "reactor_sdk/authentication"
require_relative "reactor_sdk/rate_limiter"
require_relative "reactor_sdk/connection"
require_relative "reactor_sdk/paginator"
require_relative "reactor_sdk/response_parser"
require_relative "reactor_sdk/resources/base_resource"
require_relative "reactor_sdk/resources/base_resource"
require_relative "reactor_sdk/resources/company"
require_relative "reactor_sdk/resources/property"
require_relative "reactor_sdk/resources/environment"
require_relative "reactor_sdk/resources/rule"
require_relative "reactor_sdk/resources/rule_component"
require_relative "reactor_sdk/resources/data_element"
require_relative "reactor_sdk/resources/extension"
require_relative "reactor_sdk/resources/library"
require_relative "reactor_sdk/resources/build"
require_relative "reactor_sdk/resources/revision"
require_relative "reactor_sdk/resources/audit_event"
require_relative "reactor_sdk/endpoints/base_endpoint"
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
require_relative "reactor_sdk/endpoints/audit_events"
require_relative "reactor_sdk/client"
require_relative "reactor_sdk/resources/library_with_resources"
require_relative "reactor_sdk/endpoints/revisions"
