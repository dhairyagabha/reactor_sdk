# ReactorSDK

A production-ready Ruby SDK for the [Adobe Launch Reactor API v1](https://developer.adobe.com/experience-platform/documentation/tags/api/).

Handles OAuth Server-to-Server authentication, JSON:API response parsing, cursor-based pagination, per-client rate limiting, automatic retry with exponential backoff, and a typed error hierarchy — so your application code works with clean Ruby objects instead of raw HTTP responses.

---

## Contents

- [Requirements](#requirements)
- [Installation](#installation)
- [Authentication](#authentication)
- [Quick start](#quick-start)
- [Configuration](#configuration)
- [Coverage status](#coverage-status)
- [Endpoints](#endpoints)
  - [Companies](#companies)
  - [Properties](#properties)
  - [App Configurations](#app-configurations)
  - [Callbacks](#callbacks)
  - [Secrets](#secrets)
  - [Environments](#environments)
  - [Hosts](#hosts)
  - [Rules](#rules)
  - [Rule Components](#rule-components)
  - [Data Elements](#data-elements)
  - [Extensions](#extensions)
  - [Extension Packages](#extension-packages)
  - [Extension Package Usage Authorizations](#extension-package-usage-authorizations)
  - [Libraries](#libraries)
  - [Builds](#builds)
  - [Revisions](#revisions)
  - [Audit Events](#audit-events)
  - [Profiles](#profiles)
  - [Search](#search)
  - [Notes](#notes)
- [Resources](#resources)
  - [parsed\_settings](#parsed_settings)
  - [SearchResults](#searchresults)
  - [LibraryWithResources](#librarywithresources)
  - [Revision snapshots](#revision-snapshots)
  - [Upstream library resolution](#upstream-library-resolution)
- [Error handling](#error-handling)
- [Rails integration](#rails-integration)
- [Development](#development)
- [Security](#security)
- [Contributing](#contributing)
- [License](#license)

---

## Requirements

- Ruby 3.2.0 or higher
- An [Adobe Developer Console](https://developer.adobe.com/console) project with the Adobe Launch API service added
- OAuth Server-to-Server credentials (client ID and client secret)

---

## Installation

Add to your `Gemfile`:
```ruby
gem "reactor_sdk"
```

Then run:
```bash
bundle install
```

Or install directly:
```bash
gem install reactor_sdk
```

The published gem name and the `require` path are both `reactor_sdk`.

---

## Authentication

ReactorSDK uses **OAuth Server-to-Server** authentication — the only authentication method supported by Adobe as of January 2025. JWT (Service Account) credentials are no longer supported.

To obtain credentials:

1. Sign in to [Adobe Developer Console](https://developer.adobe.com/console)
2. Create a new project or open an existing one
3. Click **Add API** and select **Adobe Launch**
4. Choose **OAuth Server-to-Server** as the credential type
5. Copy your **Client ID**, **Client Secret**, and **IMS Organisation ID**

Tokens are fetched automatically on the first API call and refreshed transparently before expiry. No manual token management is required.

---

## Quick start
```ruby
require "reactor_sdk"

client = ReactorSDK::Client.new(
  client_id:     ENV["ADOBE_CLIENT_ID"],
  client_secret: ENV["ADOBE_CLIENT_SECRET"],
  org_id:        ENV["ADOBE_IMS_ORG_ID"]
)

# List all companies accessible to your credentials
companies = client.companies.list
puts companies.first.name

# List all properties in a company
properties = client.properties.list_for_company(companies.first.id)
properties.each { |p| puts "#{p.id} — #{p.name} (#{p.platform})" }

# List all rules in a property
rules = client.rules.list_for_property(properties.first.id)
rules.each { |r| puts "#{r.id} — #{r.name} — enabled: #{r.enabled?}" }
```

---

## Configuration

All options are passed to `ReactorSDK::Client.new`:
```ruby
client = ReactorSDK::Client.new(
  # Required
  client_id:     "your-client-id",
  client_secret: "your-client-secret",
  org_id:        "your-org-id@AdobeOrg",

  # Optional
  base_url:           "https://reactor.adobe.io",  # default — override for testing
  ims_token_url:      "https://ims-na1.adobelogin.com/ims/token/v3",  # default
  timeout:            30,      # HTTP timeout in seconds, default 30
  logger:             Logger.new($stdout),  # logs all HTTP calls if provided
  auto_refresh_token: true     # auto-refresh token before expiry, default true
)
```

### Environment variables

The recommended approach is to store credentials in environment variables and never commit them to source control:
```bash
export ADOBE_CLIENT_ID="your-client-id"
export ADOBE_CLIENT_SECRET="your-client-secret"
export ADOBE_IMS_ORG_ID="your-org-id@AdobeOrg"
```
```ruby
client = ReactorSDK::Client.new(
  client_id:     ENV.fetch("ADOBE_CLIENT_ID"),
  client_secret: ENV.fetch("ADOBE_CLIENT_SECRET"),
  org_id:        ENV.fetch("ADOBE_IMS_ORG_ID")
)
```

---

## Coverage status

Checked against Adobe's official Reactor OpenAPI on March 31, 2026, ReactorSDK now exposes the currently documented Reactor endpoint families:

- Companies
- Properties
- App configurations
- Callbacks
- Secrets
- Environments
- Hosts
- Rules
- Rule components
- Data elements
- Extensions
- Extension packages
- Extension package usage authorizations
- Libraries
- Builds
- Revisions
- Notes
- Audit events
- Profiles
- Search

The previously missing endpoint families are now implemented, and audit event listing has been aligned with Adobe's current global `/audit_events` route instead of the older property-scoped path. Adobe can still add new routes over time, so it is still worth checking the official spec again before any release that aims for strict parity.

---

## Endpoints

All list methods follow pagination automatically. You never need to handle cursors or make multiple requests — every list method returns all records as a single flat array.

### Companies
```ruby
# List all companies accessible to your credentials
companies = client.companies.list
# => [#<ReactorSDK::Resources::Company id="CO123" name="Acme Corp">]

# Find a company by ID
company = client.companies.find("CO123")
```

### Properties
```ruby
# List all properties in a company
properties = client.properties.list_for_company("CO123")

# Find a property by ID
property = client.properties.find("PR123")
puts property.name      # => "My Web Property"
puts property.platform  # => "web"
puts property.enabled?  # => true
puts property.domains   # => ["example.com"]

# Create a property
property = client.properties.create(
  company_id: "CO123",
  name:       "My Web Property",
  platform:   "web",
  domains:    ["example.com"]
)

# Update a property
property = client.properties.update("PR123", { name: "Updated Name" })

# Delete a property
client.properties.delete("PR123")
```

### App Configurations
```ruby
# List app configurations for a company
configs = client.app_configurations.list_for_company("CO123")
puts configs.first.name

# Find an app configuration
config = client.app_configurations.find("AC123")
puts config.platform

# Create an app configuration
config = client.app_configurations.create(
  company_id: "CO123",
  attributes: {
    name: "iOS Push",
    app_id: "com.example.app",
    platform: "mobile"
  }
)

# Update and delete
client.app_configurations.update("AC123", name: "Updated iOS Push")
client.app_configurations.delete("AC123")
```

### Callbacks
```ruby
# List callbacks for a property
callbacks = client.callbacks.list_for_property("PR123")
puts callbacks.first.url

# Create a callback subscription
callback = client.callbacks.create(
  property_id: "PR123",
  attributes: {
    url: "https://example.com/adobe/reactor/callbacks",
    subscriptions: ["build.created", "build.completed"]
  }
)

# Update and delete
client.callbacks.update("CB123", url: "https://example.com/new-callback")
client.callbacks.delete("CB123")
```

### Environments
```ruby
# List all environments for a property
environments = client.environments.list_for_property("PR123")
environments.each { |e| puts "#{e.name} — #{e.stage}" }

# Find an environment
environment = client.environments.find("EN123")
puts environment.stage     # => "development"
puts environment.archived? # => false

# Create a personal developer sandbox environment
host = client.hosts.list_for_property("PR123").first
environment = client.environments.create(
  property_id: "PR123",
  name:        "jsmith-dev",
  stage:       "development",
  host_id:     host.id
)

# Delete an environment
client.environments.delete("EN123")
```

### Secrets
```ruby
# List secrets for a property or environment
property_secrets = client.secrets.list_for_property("PR123")
environment_secrets = client.secrets.list_for_environment("EN123")

# Create a secret for a specific environment
secret = client.secrets.create(
  property_id: "PR123",
  environment_id: "EN123",
  attributes: {
    name: "Adobe IO OAuth Secret",
    type_of: "oauth2",
    credentials: {
      access_token: "redacted"
    }
  }
)

# Trigger Adobe's test / retry actions
client.secrets.test("SE123", type_of: "oauth2")
client.secrets.retry("SE123", type_of: "oauth2")

# Traverse related resources
client.secrets.environment("SE123")
client.secrets.property("SE123")
client.secrets.data_elements("SE123")
```

### Hosts
```ruby
# List all hosts for a property
hosts = client.hosts.list_for_property("PR123")
puts hosts.first.name

# Find or create a host
host = client.hosts.find("HT123")
host = client.hosts.create(
  property_id: "PR123",
  attributes: {
    name: "SFTP Host",
    type_of: "sftp"
  }
)

# Update and delete
client.hosts.update("HT123", name: "Updated SFTP Host")
client.hosts.delete("HT123")
```

### Rules
```ruby
# List all rules for a property
rules = client.rules.list_for_property("PR123")
rules.each { |r| puts "#{r.name} — enabled: #{r.enabled?}" }

# Find a rule
rule = client.rules.find("RL123")

# Create a rule
rule = client.rules.create(
  property_id: "PR123",
  name:        "Order Confirmation",
  enabled:     true
)

# Update a rule
rule = client.rules.update("RL123", { name: "Updated Rule Name" })

# Delete a rule
client.rules.delete("RL123")
```

### Rule Components

Rule components are the individual conditions and actions that make up a rule.
```ruby
# List all components for a rule
components = client.rule_components.list_for_rule("RL123")
components.each do |c|
  puts c.name
  puts c.delegate_descriptor_id  # e.g. "core::actions::custom-code"
  puts c.order
  puts c.parsed_settings.inspect # full settings as a Ruby Hash — see parsed_settings
end

# Find a rule component
component = client.rule_components.find("RC123")
```

### Data Elements
```ruby
# List all data elements for a property
elements = client.data_elements.list_for_property("PR123")
elements.each do |e|
  puts e.name
  puts e.delegate_descriptor_id
  puts e.storage_duration
  puts e.parsed_settings.inspect # full settings as a Ruby Hash — see parsed_settings
end

# Find a data element
element = client.data_elements.find("DE123")

# Create a data element
core_extension = client.extensions
  .list_for_property("PR123")
  .find { |ext| ext.delegate_descriptor_id.start_with?("core::") }

element = client.data_elements.create(
  property_id:            "PR123",
  name:                   "Page Name",
  delegate_descriptor_id: "core::dataElements::custom-code",
  settings:               { source: "return digitalData.page.name;" }.to_json,
  extension_id:           core_extension.id,
  enabled:                true
)

# Update a data element
element = client.data_elements.update("DE123", { name: "Updated Name" })

# Delete a data element
client.data_elements.delete("DE123")
```

### Extensions
```ruby
# List all extensions installed in a property
extensions = client.extensions.list_for_property("PR123")
extensions.each { |e| puts e.delegate_descriptor_id }

# Find an extension
extension = client.extensions.find("EX123")
```

### Extension Packages
```ruby
# List published / available extension packages
packages = client.extension_packages.list
puts packages.first.name

# Upload a new package archive
package = client.extension_packages.create(package_path: "tmp/my_extension_package.zip")

# Upload a new version of an existing package
package = client.extension_packages.update(
  "EP123",
  package_path: "tmp/my_extension_package_v2.zip"
)

# Package lifecycle and relationships
client.extension_packages.private_release("EP123")
client.extension_packages.discontinue("EP123")
client.extension_packages.versions("EP123")
client.extension_packages.usage_authorizations("EP123")
```

### Extension Package Usage Authorizations
```ruby
# List all usage authorizations visible to the current credentials
authorizations = client.extension_package_usage_authorizations.list

# Grant an organization access to a private package
authorization = client.extension_package_usage_authorizations.create(
  extension_package_id: "EP123",
  authorized_org_id: "ABCDEF0123456789@AdobeOrg"
)

# Change authorization state or revoke it
client.extension_package_usage_authorizations.update("UA123", state: "approved")
client.extension_package_usage_authorizations.delete("UA123")
```

### Libraries

Libraries are the central resource in the Adobe Launch publishing workflow. They collect rules, data elements, and extensions into a deployable bundle and move through a state machine from development to production.

#### Finding libraries
```ruby
# List all libraries for a property
libraries = client.libraries.list_for_property("PR123")

# Find a library
library = client.libraries.find("LB123")
puts library.name       # => "Release 1.0"
puts library.state      # => "development"
puts library.buildable? # => true
puts library.published? # => false

# Fetch a library with all included resources and their current revision IDs
library = client.libraries.find_with_resources("LB123")
puts library.rules.length              # => 3
puts library.rules.first.revision_id  # => "RE001"
puts library.resource_index           # => { "RL123" => "RE001", ... }
```

#### Creating libraries
```ruby
library = client.libraries.create(
  property_id: "PR123",
  name:        "Release 1.0"
)
```

#### Adding resources to a library

Adds the specified resources. All existing resources already in the library are preserved.
```ruby
client.libraries.add_rules("LB123",         ["RL123", "RL456"])
client.libraries.add_data_elements("LB123", ["DE123"])
client.libraries.add_extensions("LB123",    ["EX123"])
```

#### Removing specific resources from a library

Removes only the specified resources. All other resources in the library are preserved.
```ruby
client.libraries.remove_rules("LB123",         ["RL123"])
client.libraries.remove_data_elements("LB123", ["DE123"])
client.libraries.remove_extensions("LB123",    ["EX123"])
```

#### Replacing the entire resource list for a type

Replaces the **complete** list for that resource type. Any resource not included in the new list is removed. Passing an empty array removes all resources of that type.

**Use with caution — this is a destructive operation.**
```ruby
# Only RL456 remains — RL123 is removed
client.libraries.set_rules("LB123", ["RL456"])

# Replace all data elements
client.libraries.set_data_elements("LB123", ["DE456", "DE789"])

# Remove all extensions
client.libraries.set_extensions("LB123", [])
```

#### Assigning an environment and building

A library must have an environment assigned before it can be built.
```ruby
# Assign an environment
client.libraries.assign_environment("LB123", "EN123")

# Trigger a build — compiles the library into a deployable JavaScript bundle
build = client.libraries.build("LB123")
puts build.id      # => "BL123"
puts build.status  # => "pending"
```

#### Promoting through the state machine
```ruby
# development → submitted → approved → published
# development → submitted → rejected → development

client.libraries.transition("LB123", state: "submitted")
client.libraries.transition("LB123", state: "approved")
client.libraries.transition("LB123", state: "published")

# Reject after submission
client.libraries.transition("LB123", state: "rejected")
```

#### Resolving upstream libraries
```ruby
# Returns ordered list of libraries above the target in the environment chain
# Development → [staging_library, production_library]
# Staging     → [production_library]
# Production  → []

upstream = client.libraries.upstream_libraries("LB_DEV", property_id: "PR123")
upstream.first.name  # => "Staging Library"
upstream.last.name   # => "Production Library"
```

### Builds
```ruby
# Find a build — use this to poll build status after triggering a build
build = client.builds.find("BL123")
puts build.status      # => "processing"
puts build.succeeded?  # => false
puts build.pending?    # => true
puts build.failed?     # => false

# List all builds for a library
builds = client.builds.list_for_library("LB123")

# Polling pattern — wait for a build to complete
loop do
  build = client.builds.find(build.id)
  break if build.succeeded? || build.failed?
  puts "Build #{build.status} — waiting..."
  sleep 30
end

puts build.succeeded? ? "Build complete" : "Build failed"
```

### Revisions

Revisions are point-in-time snapshots of rules, data elements, and extensions. They are the foundation of any diffing or comparison workflow.

**Key distinction:**
- `list_for_*` returns versioned resources of the matching type (`Rule`, `DataElement`, `Extension`), newest first.
- `find` returns a `Revision` snapshot when you already have a dedicated `revisions` ID, such as one exposed by a `latest_revision` relationship.
```ruby
# List all revisions for a rule
revisions = client.revisions.list_for_rule("RL123")
revisions.each { |r| puts "#{r.id} — revision #{r['revision_number']} — #{r.created_at}" }
puts revisions.first.name
puts revisions.first.enabled?

# List all revisions for a data element
revisions = client.revisions.list_for_data_element("DE123")
puts revisions.first.parsed_settings

# List all revisions for an extension
revisions = client.revisions.list_for_extension("EX123")
puts revisions.first.delegate_descriptor_id

# Fetch a specific generic revision with full entity snapshot
revision = client.revisions.find("RE123")
puts revision.id              # => "RE123"
puts revision.activity_type   # => "updated"
puts revision.entity_id       # => "RL123"
puts revision.entity_type     # => "rules"
puts revision.entity_snapshot # => { "name" => "Order Confirmation", "enabled" => true, ... }
```

### Audit Events
```ruby
# List all audit events from Adobe's current global endpoint
events = client.audit_events.list
events.each { |e| puts "#{e.type_of} — #{e.entity_display_name} — #{e.created_at}" }

# Filter events after a specific timestamp
events = client.audit_events.list(since: "2024-06-01T00:00:00.000Z")

# Additional supported filters
events = client.audit_events.list(
  updated_at: "2024-06-01T00:00:00.000Z",
  type_of: "property.updated"
)

# Find a specific audit event
event = client.audit_events.find("AE123")
```

`list_for_property("PR123")` remains available as a backward-compatible wrapper, but Adobe's current official Reactor API documents the listing route as global `/audit_events`.

### Profiles
```ruby
profile = client.profiles.current
puts profile.email
puts profile.display_name
puts profile.rights.inspect
```

### Search
```ruby
results = client.search.perform(
  query: "Release",
  resource_types: %w[libraries rules callbacks],
  size: 25
)

puts results.total_hits
results.each { |resource| puts "#{resource.type} #{resource.id}" }
```

### Notes
```ruby
# Find a single note directly
note = client.notes.find("NOTE123")

# List or create notes through the owning resource endpoint
client.properties.list_notes("PR123")
client.properties.create_note("PR123", "Ready for review")

client.rules.list_notes("RL123")
client.rule_components.create_note("RC123", "Move this above the analytics action")
client.secrets.create_note("SE123", "Rotate after staging validation")
```

---

## Resources

All API responses are parsed into typed Ruby resource objects. Every resource exposes its fields as named methods — no hash key access required.

### Common fields

Every resource has:
```ruby
resource.id          # Adobe resource ID string
resource.type        # JSON:API type string (e.g. "rules")
resource.attributes  # Raw attributes hash — always available
resource.meta        # Meta hash from the API response
resource[key]        # Access any attribute by name
resource.to_h        # Hash representation
resource == other    # Equality by id and type
```

### parsed\_settings

`RuleComponent` and `DataElement` both expose a `parsed_settings` method that returns the `settings` field as a Ruby Hash.

The `settings` field in the Reactor API varies significantly across extension types:

- **Core custom code actions and data elements** — JSON-encoded string containing a `source` key with JavaScript or HTML
- **Adobe Web SDK actions** — JSON-encoded string containing `xdm` and `data` objects
- **Adobe Analytics actions** — JSON-encoded string containing variable mappings and custom setup blocks
- **Third-party extensions** — any structure the extension author defines

`parsed_settings` handles all of these uniformly and safely:
```ruby
component = client.rule_components.find("RC123")

# Core custom code — JavaScript
component.parsed_settings
# => { "source" => "var x = _satellite.getVar('page_name');", "language" => "javascript" }

# Core custom code — HTML
component.parsed_settings
# => { "source" => "<div class='modal'>...</div>", "language" => "html" }

# Adobe Web SDK — XDM object
component.parsed_settings
# => { "xdm" => { "eventType" => "web.webpagedetails.pageViews", ... }, "data" => { ... } }

# Adobe Analytics — variable mappings
component.parsed_settings
# => { "trackerProperties" => { "eVars" => [...], "events" => [...] }, "customSetup" => { ... } }

# Nil, blank, or unparseable — never raises, always returns Hash
component.parsed_settings  # => {}

# Raw value is always preserved unchanged regardless of what parsed_settings returns
component.settings         # => original string exactly as Adobe returned it
```

The same method is available on `DataElement`:
```ruby
element = client.data_elements.find("DE123")
element.parsed_settings  # => { "source" => "return digitalData.page.name;", "language" => "javascript" }
element.settings         # => raw string unchanged
```

### SearchResults

`client.search.perform` returns a `SearchResults` wrapper instead of a plain array:
```ruby
results = client.search.perform(query: "Checkout", resource_types: %w[rules libraries])

results.total_hits  # => 7
results.results     # => [#<Rule ...>, #<Library ...>, ...]
results.each do |resource|
  puts "#{resource.type} #{resource.id}"
end
```

### LibraryWithResources

`client.libraries.find_with_resources` returns a `LibraryWithResources` object — a richer library resource that includes all associated rules, data elements, and extensions with their current revision IDs attached.
```ruby
library = client.libraries.find_with_resources("LB123")

# Access included resources as typed objects
library.rules           # => [#<Rule id="RL123" ...>, ...]
library.data_elements   # => [#<DataElement id="DE123" ...>, ...]
library.extensions      # => [#<Extension id="EX123" ...>, ...]

# Each resource has its current revision ID attached
library.rules.first.revision_id           # => "RE001"
library.data_elements.first.revision_id   # => "RE010"
library.extensions.first.revision_id      # => "RE020"

# Flat index of all resources → revision IDs across all types
# Used to compare two libraries and detect what changed
library.resource_index
# => { "RL123" => "RE001", "RL456" => "RE002", "DE123" => "RE010", "EX123" => "RE020" }

# All resources as a flat array regardless of type
library.all_resources  # => [Rule, Rule, DataElement, Extension]

# Standard library convenience methods
library.buildable?  # => true
library.published?  # => false
```

### Revision snapshots

A `Revision` fetched via `find` contains the full state of the revisioned resource at that point in time:
```ruby
revision = client.revisions.find("RE001")

revision.entity_id       # => "RL123"
revision.entity_type     # => "rules"
revision.activity_type   # => "updated"
revision.created_at      # => "2024-06-01T14:32:00.000Z"

# Full attributes of the resource at this revision — use this for comparison
revision.entity_snapshot
# => {
#   "name"       => "Order Confirmation",
#   "enabled"    => true,
#   "created_at" => "2024-01-01T00:00:00.000Z",
#   ...
# }
```

The list methods return full versioned resources of the matching type. Use `find` only when another API response gives you a dedicated `revisions` ID and you need the generic snapshot wrapper.

### Upstream library resolution

In Adobe Launch, environments are arranged in a promotion hierarchy:
```
Personal Dev → Development → Staging → Production
```

Changes flow upward — resources must pass through Development and Staging before reaching Production. **Upstream** means closer to Production.

`upstream_libraries` returns the ordered list of libraries above a given target:
```ruby
# Target is Development → [staging_library, production_library]
upstream = client.libraries.upstream_libraries("LB_DEV", property_id: "PR123")
upstream.first.name  # => "Staging Library"
upstream.last.name   # => "Production Library"

# Target is Staging → [production_library]
upstream = client.libraries.upstream_libraries("LB_STG", property_id: "PR123")

# Target is Production → [] (nothing upstream)
upstream = client.libraries.upstream_libraries("LB_PRD", property_id: "PR123")
# => []
```

**Typical upstream resolution pattern** — finding the nearest upstream version of a resource when it does not exist in the target library:
```ruby
source_library = client.libraries.find_with_resources("LB_PERSONAL")
target_library = client.libraries.find_with_resources("LB_DEV")
upstream       = client.libraries.upstream_libraries("LB_DEV", property_id: "PR123")

source_library.rules.each do |rule|
  if target_library.resource_index.key?(rule.id)
    # Resource exists in target — fetch both revisions for comparison
    source_revision = client.revisions.find(rule.revision_id)
    target_revision = client.revisions.find(target_library.resource_index[rule.id])
    # Compare source_revision.entity_snapshot vs target_revision.entity_snapshot

  else
    # Resource not in target — walk upstream to find nearest version
    upstream_revision_id = upstream.lazy.filter_map do |lib|
      upstream_with_resources = client.libraries.find_with_resources(lib.id)
      upstream_with_resources.resource_index[rule.id]
    end.first

    if upstream_revision_id
      upstream_revision = client.revisions.find(upstream_revision_id)
      # Compare rule against upstream_revision.entity_snapshot
    else
      # Resource is net new — no upstream version exists anywhere in the chain
    end
  end
end
```

---

## Error handling

All errors inherit from `ReactorSDK::Error` so you can rescue broadly or narrowly:
```ruby
# Rescue any SDK error
begin
  client.properties.find("PR_INVALID")
rescue ReactorSDK::Error => e
  puts "SDK error: #{e.message} (HTTP #{e.status})"
end

# Rescue specific errors
begin
  client.libraries.add_rules("LB123", ["RL123"])
rescue ReactorSDK::ResourceNotFoundError => e
  puts "Library or rule not found"
rescue ReactorSDK::AuthenticationError => e
  puts "Authentication failed — check your credentials"
rescue ReactorSDK::AuthorizationError => e
  puts "Token lacks permission for this resource"
rescue ReactorSDK::RateLimitError => e
  puts "Rate limited — retry after #{e.retry_after} seconds"
  sleep e.retry_after
  retry
rescue ReactorSDK::UnprocessableEntityError => e
  puts "Validation failed: #{e.validation_errors.inspect}"
rescue ReactorSDK::ServerError => e
  puts "Adobe API server error (HTTP #{e.status})"
rescue ReactorSDK::ParseError => e
  puts "Could not parse API response"
end
```

### Error classes

| Class | HTTP status | When raised |
|---|---|---|
| `ReactorSDK::Error` | — | Base class for all SDK errors |
| `ReactorSDK::AuthenticationError` | 401 | Token fetch failed or token rejected |
| `ReactorSDK::AuthorizationError` | 403 | Token lacks permission for the resource |
| `ReactorSDK::ResourceNotFoundError` | 404 | Requested resource does not exist |
| `ReactorSDK::UnprocessableEntityError` | 422 | Request payload failed Adobe validation |
| `ReactorSDK::RateLimitError` | 429 | Rate limit hit after all retries exhausted |
| `ReactorSDK::ServerError` | 5xx | Adobe API server error after all retries |
| `ReactorSDK::ParseError` | — | Response body was not valid JSON |
| `ReactorSDK::ConfigurationError` | — | Missing or blank required credential |

---

## Rails integration

### Optional initializer for a default client
```ruby
# config/initializers/reactor_sdk.rb

REACTOR_CLIENT = ReactorSDK::Client.new(
  client_id:     Rails.application.credentials.adobe[:client_id],
  client_secret: Rails.application.credentials.adobe[:client_secret],
  org_id:        Rails.application.credentials.adobe[:org_id],
  logger:        Rails.logger
)
```

The initializer above is only an application convenience. ReactorSDK itself does not use a global singleton internally. Every call to `ReactorSDK::Client.new` creates an independent client with its own configuration, token cache, Faraday connection, and rate limiter.

### Dynamic clients from stored credentials
```ruby
# app/services/reactor_client_factory.rb

class ReactorClientFactory
  def self.build(credential_record, logger: Rails.logger)
    ReactorSDK::Client.new(
      client_id:     credential_record.client_id,
      client_secret: credential_record.client_secret,
      org_id:        credential_record.org_id,
      logger:        logger
    )
  end
end
```

```ruby
# app/jobs/sync_adobe_property_job.rb

class SyncAdobePropertyJob < ApplicationJob
  def perform(adobe_credential_id)
    credential = AdobeCredential.find(adobe_credential_id)
    client     = ReactorClientFactory.build(credential)
    PropertySyncService.new(org: credential.org, client: client).call
  end
end
```

This is the recommended pattern when your application stores multiple Adobe credential sets in the database. Build a client per credential record at the service or job boundary, rather than forcing all requests through one initializer-backed constant.

### Service object pattern
```ruby
# app/services/property_sync_service.rb

class PropertySyncService
  def initialize(org:, client: REACTOR_CLIENT)
    @org    = org
    @client = client
  end

  def call
    companies  = @client.companies.list
    properties = @client.properties.list_for_company(companies.first.id)
    properties.map { |p| upsert_property(p) }
  end

  private

  def upsert_property(adobe_property)
    Property.find_or_initialize_by(
      org:               @org,
      adobe_property_id: adobe_property.id
    ).tap do |p|
      p.name     = adobe_property.name
      p.platform = adobe_property.platform
      p.save!
    end
  end
end
```

### Full publish workflow example
```ruby
# app/services/library_publish_service.rb

class LibraryPublishService
  POLL_INTERVAL = 30 # seconds
  MAX_WAIT      = 600 # 10 minutes

  def initialize(library_id:, environment_id:, client: REACTOR_CLIENT)
    @library_id     = library_id
    @environment_id = environment_id
    @client         = client
  end

  def call
    assign_environment
    build = trigger_build
    wait_for_build(build)
    publish
  end

  private

  def assign_environment
    @client.libraries.assign_environment(@library_id, @environment_id)
  end

  def trigger_build
    @client.libraries.build(@library_id)
  end

  def wait_for_build(build)
    elapsed = 0
    loop do
      build = @client.builds.find(build.id)
      return if build.succeeded?
      raise "Build failed" if build.failed?
      raise "Build timed out after #{MAX_WAIT}s" if elapsed >= MAX_WAIT
      sleep POLL_INTERVAL
      elapsed += POLL_INTERVAL
    end
  end

  def publish
    @client.libraries.transition(@library_id, state: "submitted")
    @client.libraries.transition(@library_id, state: "approved")
    @client.libraries.transition(@library_id, state: "published")
  end
end
```

### Credentials setup
```bash
rails credentials:edit
```
```yaml
adobe:
  client_id: your-client-id
  client_secret: your-client-secret
  org_id: your-org-id@AdobeOrg
```

---

## Development

### Setup
```bash
git clone https://github.com/dhairyagabha/reactor_sdk
cd reactor_sdk
bundle install
```

If you use `rbenv`, the repository includes a pinned development Ruby in `.ruby-version`:
```bash
rbenv install -s "$(cat .ruby-version)"
rbenv local "$(cat .ruby-version)"
bundle install
```

### Running tests
```bash
bundle exec rspec
```

With documentation output:
```bash
bundle exec rspec --format documentation
```

Run a single spec file:
```bash
bundle exec rspec spec/reactor_sdk/endpoints/libraries_spec.rb
```

### Running RuboCop
```bash
bundle exec rubocop
```

### Running the full quality gate
```bash
bundle exec rake
```

CI runs the test suite across supported Ruby versions and runs RuboCop on the primary development Ruby.

### Recording VCR cassettes against the real API

By default all tests use WebMock stubs — no real API calls are made. To record new cassettes against the real Adobe API:
```bash
ADOBE_CLIENT_ID=xxx \
ADOBE_CLIENT_SECRET=xxx \
ADOBE_IMS_ORG_ID=xxx \
VCR_RECORD=new bundle exec rspec spec/path/to/spec.rb
```

To re-record all cassettes:
```bash
VCR_RECORD=all bundle exec rspec
```

---

## Security

Please report suspected vulnerabilities privately as described in [SECURITY.md](SECURITY.md).

---

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/my-feature`)
3. Write tests for your change
4. Make your change
5. Ensure the default quality gate passes (`bundle exec rake`)
6. Update docs and changelog entries when behavior changes
7. Open a pull request

Please follow the coding standards in `CONTRIBUTING.md`.

---

## License

Released under the MIT License. See [LICENSE.txt](LICENSE.txt) for details.

---

## Acknowledgements

Built on top of the [Adobe Launch Reactor API v1](https://developer.adobe.com/experience-platform/documentation/tags/api/).
Adobe, Adobe Launch, and Adobe Experience Platform are trademarks of Adobe Inc.
This gem is not affiliated with or endorsed by Adobe.
