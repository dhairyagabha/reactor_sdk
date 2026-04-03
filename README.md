<p align="center">
  <img src=".github/assets/reactor-sdk-lockup.svg" alt="ReactorSDK" width="520">
</p>

<p align="center">
  <a href="https://github.com/dhairyagabha/reactor_sdk/actions/workflows/main.yml">
    <img src="https://github.com/dhairyagabha/reactor_sdk/actions/workflows/main.yml/badge.svg" alt="CI">
  </a>
  <a href="https://rubygems.org/gems/reactor_sdk">
    <img src="https://img.shields.io/gem/v/reactor_sdk.svg" alt="RubyGems version">
  </a>
</p>

<p align="center">
  <a href="https://reactor-sdk.dhairyagabhawala.com">Documentation</a>
  ·
  <a href="https://github.com/dhairyagabha/reactor_sdk/blob/main/CHANGELOG.md">Changelog</a>
  ·
  <a href="https://rubygems.org/gems/reactor_sdk">RubyGems</a>
  ·
  <a href="https://github.com/dhairyagabha/reactor_sdk">GitHub</a>
</p>

# ReactorSDK

`reactor_sdk` is a Ruby SDK for the Adobe Launch / Data Collection Reactor API. It handles OAuth Server-to-Server authentication, JSON:API parsing, pagination, retries, rate limiting, revision snapshots, and review-friendly comparison helpers so application code can work with typed Ruby objects instead of raw HTTP payloads.

## Features

- OAuth Server-to-Server authentication with automatic token refresh
- Typed resource objects across companies, properties, rules, data elements, extensions, libraries, builds, revisions, notes, and more
- Automatic pagination for list endpoints
- Consistent error classes and retry behavior around Adobe API failures
- Library-aware review helpers for rules, data elements, and extensions
- Upstream-chain lookup for resource review across Development, Staging, and Production
- Library-to-library comparison output with status, revision IDs, and normalized review payloads

## Installation

Add the gem to your application:

```ruby
gem "reactor_sdk"
```

Then install it:

```bash
bundle install
```

Or install directly:

```bash
gem install reactor_sdk
```

## Authentication and Configuration

ReactorSDK uses Adobe OAuth Server-to-Server credentials. JWT / Service Account credentials are not supported.

```ruby
require "reactor_sdk"

client = ReactorSDK::Client.new(
  client_id: ENV.fetch("ADOBE_CLIENT_ID"),
  client_secret: ENV.fetch("ADOBE_CLIENT_SECRET"),
  org_id: ENV.fetch("ADOBE_IMS_ORG_ID")
)
```

Optional configuration is passed to the same client constructor:

```ruby
client = ReactorSDK::Client.new(
  client_id: "your-client-id",
  client_secret: "your-client-secret",
  org_id: "your-org-id@AdobeOrg",
  base_url: "https://reactor.adobe.io",
  ims_token_url: "https://ims-na1.adobelogin.com/ims/token/v3",
  timeout: 30,
  logger: Logger.new($stdout),
  auto_refresh_token: true
)
```

## Quick Start

```ruby
require "reactor_sdk"

client = ReactorSDK::Client.new(
  client_id: ENV.fetch("ADOBE_CLIENT_ID"),
  client_secret: ENV.fetch("ADOBE_CLIENT_SECRET"),
  org_id: ENV.fetch("ADOBE_IMS_ORG_ID")
)

# List companies available to the credential set.
companies = client.companies.list
company = companies.first

# List properties inside the company.
properties = client.properties.list_for_company(company.id)
property = properties.first

# List rules in the property.
rules = client.rules.list_for_property(property.id)
puts rules.first&.name
```

## Review and Promotion Workflows

ReactorSDK includes higher-level helpers for review tooling and release workflows, not just CRUD wrappers.

### Work with a Library Snapshot

```ruby
# LB_DEV = development library ID.
# PR123 = property ID.
snapshot = client.libraries.find_snapshot("LB_DEV", property_id: "PR123")

# Point-in-time rule components associated with the rule inside this library snapshot.
snapshot.rule_components_for_rule("RL123").map(&:id)

# Snapshot-scoped impact analysis for a data element.
snapshot.impacted_rules_for("DE123").map(&:name)
```

### Build Comprehensive Review Objects

```ruby
rule_review = client.rules.find_comprehensive(
  "RL123",
  library_id: "LB_DEV",
  property_id: "PR123"
)

data_element_review = client.data_elements.find_comprehensive(
  "DE123",
  library_id: "LB_DEV",
  property_id: "PR123"
)

extension_review = client.extensions.find_comprehensive(
  "EX123",
  library_id: "LB_DEV",
  property_id: "PR123"
)

puts rule_review.normalized_json
puts data_element_review.normalized_json
puts extension_review.normalized_json
```

These comprehensive review objects include the resource plus the associated records a reviewer usually needs:

- Rules include rule components
- Data elements include referenced data elements and impacted rules
- Extensions include dependent data elements, rule components, and rules

### Resolve Upstream Versions

```ruby
chain = client.rules.comprehensive_upstream_chain(
  "RL123",
  library_id: "LB_DEV",
  property_id: "PR123"
)

staging_entry = chain.entries.find { |entry| entry.stage == "staging" }

puts chain.target_revision_id
puts staging_entry&.revision_id
puts staging_entry&.normalized_json
```

### Compare Two Libraries

```ruby
# Compare Development against Staging.
comparison = client.libraries.compare(
  "LB_DEV",
  baseline_library_id: "LB_STG",
  property_id: "PR123"
)

comparison.entries.each do |entry|
  puts "#{entry.resource_type} #{entry.resource_id} #{entry.status}"
  puts entry.current_revision_id
  puts entry.baseline_revision_id
end

# Inspect normalized output for one entry.
entry = comparison.entries.first
puts entry.current_normalized_json
puts entry.baseline_normalized_json
```

Sample comparison output:

```ruby
# Example status rows you might print from comparison.entries:
# rules RL100 modified
# current revision  = RE_CUR_RULE
# baseline revision = RE_BASE_RULE
#
# rules RL200 added
# current revision  = RE_ADDED
# baseline revision = nil
#
# data_elements DE200 removed
# current revision  = nil
# baseline revision = RE_REMOVED
#
# extensions EX100 unchanged
# current revision  = RE_EX
# baseline revision = RE_EX
```

Comparison is performed across the library's top-level rules, data elements, and extensions. Rule components are still included in the comprehensive rule payload so rule diffs remain readable.

## Endpoint Coverage

The SDK currently exposes these endpoint families:

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

## Documentation

Full guides, API reference pages, example payloads, and review-workflow documentation are available at:

- https://reactor-sdk.dhairyagabhawala.com

## Development

Install dependencies:

```bash
bundle install
```

Run the test suite:

```bash
bundle exec rspec
```

Run RuboCop:

```bash
bundle exec rubocop
```

Build the gem:

```bash
gem build reactor_sdk.gemspec
```

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for contribution and development guidance.
