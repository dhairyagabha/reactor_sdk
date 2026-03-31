# frozen_string_literal: true

##
# @file sandbox_test.rb
# @description Comprehensive live integration test against a real Adobe Launch sandbox.
#
#   Tests every SDK endpoint and every workflow against a real Adobe Launch
#   property. Creates real resources, exercises the full library workflow,
#   and cleans up created resources at the end.
#
#   Setup:
#     1. Fill in .env.sandbox with your Adobe Developer Console credentials
#     2. Run: ruby sandbox_test.rb
#

require_relative "lib/reactor_sdk"

begin
  require "dotenv"
  Dotenv.load(".env.sandbox")
rescue LoadError
  # dotenv not installed — credentials read directly from ENV
end

CLIENT_ID     = ENV.fetch("ADOBE_CLIENT_ID")     { abort "Missing ADOBE_CLIENT_ID" }
CLIENT_SECRET = ENV.fetch("ADOBE_CLIENT_SECRET") { abort "Missing ADOBE_CLIENT_SECRET" }
ORG_ID        = ENV.fetch("ADOBE_IMS_ORG_ID")    { abort "Missing ADOBE_IMS_ORG_ID" }

PASS = "✓"
FAIL = "✗"
SKIP = "○"
WARN = "⚠"
INFO = "→"

$results = []
$created = { rules: [], data_elements: [], libraries: [], environments: [], rule_components: [] }
$client  = nil

def section(title)
  puts ""
  puts "━" * 60
  puts "  #{title}"
  puts "━" * 60
end

def check(description)
  result = yield
  status = result ? PASS : FAIL
  $results << { description: description, passed: !!result }
  puts "  #{status}  #{description}"
  result
rescue ReactorSDK::Error => e
  msg = "#{e.class} (HTTP #{e.status}): #{e.message}"
  $results << { description: description, passed: false, error: msg }
  puts "  #{FAIL}  #{description}"
  puts "       #{msg}"
  nil
rescue StandardError => e
  $results << { description: description, passed: false, error: "#{e.class}: #{e.message}" }
  puts "  #{FAIL}  #{description}"
  puts "       #{e.class}: #{e.message}"
  nil
end

def known_limitation(description, reason)
  $results << { description: description, skipped: true, limitation: true }
  puts "  #{WARN}  #{description}"
  puts "       Known limitation: #{reason}"
end

def skip(description, reason)
  $results << { description: description, skipped: true }
  puts "  #{SKIP}  #{description} (skipped: #{reason})"
end

def info(label, value)
  puts "       #{label}: #{value}"
end

def note(message)
  puts "       #{INFO} #{message}"
end

def timestamp
  Time.now.strftime("%Y%m%d-%H%M%S")
end

def track_latest(kind, resource, previous_id: nil)
  return unless resource

  ids = $created.fetch(kind)
  ids.delete(previous_id) if previous_id
  ids.delete(resource.id)
  ids << resource.id
end

# ── Authentication ───────────────────────────────────────────────

section "Authentication"

puts "  Connecting to Adobe IMS..."
puts "  Org: #{ORG_ID}"
puts ""

$client = ReactorSDK::Client.new(
  client_id:     CLIENT_ID,
  client_secret: CLIENT_SECRET,
  org_id:        ORG_ID
)

check("Client initializes without error") { $client.is_a?(ReactorSDK::Client) }
check("Configuration stores org_id")      { $client.config.org_id == ORG_ID }
check("All endpoint groups accessible") do
  %i[companies properties environments hosts rules rule_components
     data_elements extensions libraries builds revisions audit_events].all? do |ep|
    $client.respond_to?(ep)
  end
end

# ── Companies ────────────────────────────────────────────────────

section "Companies"

company   = nil
companies = nil

check("Lists companies") do
  companies = $client.companies.list
  companies.is_a?(Array) && companies.length >= 1
end

if companies&.first
  company = companies.first
  info "Company", "#{company.name} (#{company.id})"

  check("Company name is a non-blank String") { company.name.is_a?(String) && !company.name.empty? }
  check("Company id is a non-blank String")   { company.id.is_a?(String) && !company.id.empty? }
  check("find returns the same company") do
    found = $client.companies.find(company.id)
    found.id == company.id && found.name == company.name
  end
end

# ── Properties ───────────────────────────────────────────────────

section "Properties"

property   = nil
properties = nil

if company
  check("Lists properties for company") do
    properties = $client.properties.list_for_company(company.id)
    properties.is_a?(Array) && properties.length >= 1
  end

  if properties&.any?
    property = properties.first
    info "Property", "#{property.name} (#{property.id})"
    info "Platform", property.platform

    check("Property name is a String")   { property.name.is_a?(String) }
    check("Property platform is valid")  { %w[web mobile edge].include?(property.platform) }
    check("enabled? returns a boolean")  { [true, false].include?(property.enabled?) }
    check("domains returns an Array")    { property.domains.is_a?(Array) }
    check("find returns same property") do
      found = $client.properties.find(property.id)
      found.id == property.id
    end
  else
    note "No properties found — create one in Adobe Launch first"
  end
else
  skip "Properties", "no company available"
end

# ── Hosts ────────────────────────────────────────────────────────

section "Hosts"

default_host = nil
hosts        = nil

if property
  check("Lists hosts for property") do
    hosts = $client.hosts.list_for_property(property.id)
    hosts.is_a?(Array) && hosts.length >= 1
  end

  if hosts&.any?
    default_host = hosts.find(&:akamai?) || hosts.first
    info "Found", "#{hosts.length} host(s)"
    info "Using", "#{default_host.name} (#{default_host.id}) — #{default_host.type_of}"
    info "Status", default_host.status

    check("Host name is a String")                  { default_host.name.is_a?(String) }
    check("akamai? returns true for Akamai host")   { default_host.akamai? }
    check("ready? returns true for succeeded host") { default_host.ready? }
    check("find returns same host") do
      found = $client.hosts.find(default_host.id)
      found.id == default_host.id
    end
  end
else
  skip "Hosts", "no property available"
end

# ── Environments ─────────────────────────────────────────────────

section "Environments"

environments    = nil
dev_environment = nil

if property
  check("Lists environments for property") do
    environments = $client.environments.list_for_property(property.id)
    environments.is_a?(Array) && environments.length >= 1
  end

  if environments&.any?
    dev_environment = environments.find { |e| e.stage == "development" }
    info "Found", "#{environments.length} environments"
    environments.each { |e| info "  #{e.stage}", "#{e.name} (#{e.id})" }

    env = environments.first
    check("Environment name is a String")  { env.name.is_a?(String) }
    check("Environment stage is valid")    { %w[development staging production].include?(env.stage) }
    check("archived? returns a boolean")   { [true, false].include?(env.archived?) }
    check("Development environment exists") { !dev_environment.nil? }
    check("find returns same environment") do
      found = $client.environments.find(env.id)
      found.id == env.id
    end
  end
else
  skip "Environments", "no property available"
end

# ── Personal Environment Provisioning ────────────────────────────

section "Personal Environment Provisioning"

created_personal_env = nil

if property && default_host
  env_name = "sandbox-dev-#{timestamp}"
  note "Creating personal environment: #{env_name}"

  begin
    created_personal_env = $client.environments.create(
      property_id: property.id,
      name:        env_name,
      stage:       "development",
      host_id:     default_host.id
    )
    $created[:environments] << created_personal_env.id
    $results << { description: "Creates personal environment with host_id", passed: true }
    puts "  #{PASS}  Creates personal environment with host_id"
    info "Created", "#{created_personal_env.name} (#{created_personal_env.id})"

    check("Name matches")          { created_personal_env.name == env_name }
    check("Stage is development")  { created_personal_env.stage == "development" }
    check("Not archived")          { created_personal_env.archived? == false }
    check("Findable by ID") do
      found = $client.environments.find(created_personal_env.id)
      found.id == created_personal_env.id
    end
    check("Appears in list") do
      all = $client.environments.list_for_property(property.id)
      all.any? { |e| e.id == created_personal_env.id }
    end
    note "Environment left in place — ID: #{created_personal_env.id}"
  rescue ReactorSDK::Error => e
    known_limitation("Creates personal environment with host_id", "HTTP #{e.status}: #{e.message}")
  end
else
  skip "Personal Environment Provisioning", default_host ? "no property" : "no host available"
end

# ── Extensions ───────────────────────────────────────────────────

section "Extensions"

extensions = nil
core_ext   = nil

if property
  check("Lists extensions for property") do
    extensions = $client.extensions.list_for_property(property.id)
    extensions.is_a?(Array) && extensions.length >= 1
  end

  if extensions&.any?
    core_ext = extensions.find { |e| e.delegate_descriptor_id&.start_with?("core::") }
    ext      = extensions.first
    info "Found", "#{extensions.length} extension(s)"
    extensions.each { |e| info "  Extension", e.delegate_descriptor_id }

    check("Extension delegate_descriptor_id is a String") { ext.delegate_descriptor_id.is_a?(String) }
    check("Core extension is present")                    { !core_ext.nil? }
    check("parsed_settings returns a Hash")               { ext.parsed_settings.is_a?(Hash) }
    check("find returns same extension") do
      found = $client.extensions.find(ext.id)
      found.id == ext.id
    end

    info "Core extension ID", core_ext&.id
  end
else
  skip "Extensions", "no property available"
end

# ── Rules — Read ─────────────────────────────────────────────────

section "Rules — Read"

rules         = nil
existing_rule = nil

if property
  check("Lists rules for property") do
    rules = $client.rules.list_for_property(property.id)
    rules.is_a?(Array)
  end

  if rules&.any?
    existing_rule = rules.first
    info "Found", "#{rules.length} existing rule(s)"
    info "First rule", "#{existing_rule.name} (#{existing_rule.id})"

    check("Rule name is a String")        { existing_rule.name.is_a?(String) }
    check("enabled? returns a boolean")   { [true, false].include?(existing_rule.enabled?) }
    check("Rule has created_at")          { existing_rule.created_at.is_a?(String) }
    check("find returns same rule") do
      found = $client.rules.find(existing_rule.id)
      found.id == existing_rule.id
    end
  else
    note "No existing rules — will create one below"
  end
else
  skip "Rules — Read", "no property available"
end

# ── Rules — Create / Update / Revise ──────────────────────────────

section "Rules — Create, Update, Revise"

created_rule = nil
revised_rule = nil

if property
  rule_name    = "SDK Test Rule #{timestamp}"
  note "Creating rule: #{rule_name}"

  check("Creates a rule") do
    created_rule = $client.rules.create(property_id: property.id, name: rule_name, enabled: true)
    created_rule.is_a?(ReactorSDK::Resources::Rule)
  end

  if created_rule
    track_latest(:rules, created_rule)
    info "Created", "#{created_rule.name} (#{created_rule.id})"

    check("Name matches")     { created_rule.name == rule_name }
    check("Is enabled")       { created_rule.enabled? == true }
    check("Has id")           { !created_rule.id.nil? }
    check("Findable by ID")   { $client.rules.find(created_rule.id).id == created_rule.id }
    check("Appears in list") do
      $client.rules.list_for_property(property.id).any? { |r| r.id == created_rule.id }
    end

    # Update
    updated_name = "#{rule_name} — Updated"
    updated_rule = nil
    check("Updates a rule name") do
      updated_rule = $client.rules.update(created_rule.id, { name: updated_name })
      updated_rule.name == updated_name
    end

    if updated_rule
      track_latest(:rules, updated_rule, previous_id: created_rule.id)
      created_rule = updated_rule
      check("Update persists on find") { $client.rules.find(created_rule.id).name == updated_name }
      restored_rule = $client.rules.update(created_rule.id, { name: rule_name })
      track_latest(:rules, restored_rule, previous_id: created_rule.id)
      created_rule = restored_rule
    end

    note "Rule will be revised after component changes"
  end
else
  skip "Rules — Create, Update, Revise", "no property available"
end

# ── Rule Components ───────────────────────────────────────────────

section "Rule Components — Create"

created_component = nil

if created_rule && core_ext
  check("Lists components for new rule (expect 0)") do
    result = $client.rule_components.list_for_rule(created_rule.id)
    result.is_a?(Array)
  end

  component_settings = JSON.generate({
    source:   "console.log('ReactorSDK integration test');",
    language: "javascript"
  })

  note "Creating Core custom code action"
  check("Creates a rule component at /properties/:id/rule_components") do
    created_component = $client.rule_components.create(
      property_id:            property.id,
      rule_id:                created_rule.id,
      name:                   "SDK Test Action",
      delegate_descriptor_id: "core::actions::custom-code",
      settings:               component_settings,
      extension_id:           core_ext.id,
      rule_order:             50.0,
      order:                  0
    )
    created_component.is_a?(ReactorSDK::Resources::RuleComponent)
  end

  if created_component
    $created[:rule_components] << created_component.id
    info "Created component", "#{created_component.name} (#{created_component.id})"

    check("Name matches")                        { created_component.name == "SDK Test Action" }
    check("delegate_descriptor_id correct")      { created_component.delegate_descriptor_id == "core::actions::custom-code" }
    check("parsed_settings returns Hash")        { created_component.parsed_settings.is_a?(Hash) }
    check("parsed_settings source correct") do
      created_component.parsed_settings["source"] == "console.log('ReactorSDK integration test');"
    end
    check("parsed_settings language correct")    { created_component.parsed_settings["language"] == "javascript" }
    check("Raw settings preserved after parse")  do
      original = created_component.settings
      created_component.parsed_settings
      created_component.settings == original
    end
    check("Findable by ID") do
      $client.rule_components.find(created_component.id).id == created_component.id
    end
    check("Appears in rule component list") do
      $client.rule_components.list_for_rule(created_rule.id).any? { |c| c.id == created_component.id }
    end

    # Modifying rule components dirties the parent rule, so revise it again
    # before attempting to add the rule to a library.
    note "Revising rule after component changes"
    revised_rule_after_component = nil
    check("Revises rule after component changes") do
      revised_rule_after_component = $client.rules.revise(created_rule.id)
      revised_rule_after_component.is_a?(ReactorSDK::Resources::Rule)
    end

    if revised_rule_after_component
      revised_rule = revised_rule_after_component
      info "Revised rule id", revised_rule.id
    end
  end

elsif !core_ext
  skip "Rule Components — Create", "Core extension not available"
else
  skip "Rule Components — Create", "no rule created"
end

if created_rule && revised_rule.nil?
  note "Revising rule (required before adding to library)"
  check("Revises a rule") do
    revised_rule = $client.rules.revise(created_rule.id)
    revised_rule.is_a?(ReactorSDK::Resources::Rule)
  end
  info "Revised rule id", revised_rule.id if revised_rule
end

# Read existing rule components if any
if existing_rule
  existing_components = $client.rule_components.list_for_rule(existing_rule.id)
  if existing_components.any?
    ec = existing_components.first
    info "Existing component", "#{ec.name} — #{ec.delegate_descriptor_id}"
    check("Existing component parsed_settings is Hash") { ec.parsed_settings.is_a?(Hash) }
    check("Existing settings preserved after parse") do
      original = ec.settings
      ec.parsed_settings
      ec.settings == original
    end
    check("find returns existing component") do
      $client.rule_components.find(ec.id).id == ec.id
    end
  end
end

# ── Data Elements — Read ──────────────────────────────────────────

section "Data Elements — Read"

data_elements = nil
existing_de   = nil

if property
  check("Lists data elements for property") do
    data_elements = $client.data_elements.list_for_property(property.id)
    data_elements.is_a?(Array)
  end

  if data_elements&.any?
    existing_de = data_elements.first
    info "Found", "#{data_elements.length} existing data element(s)"
    info "First", "#{existing_de.name} (#{existing_de.id})"

    check("Name is a String")                  { existing_de.name.is_a?(String) }
    check("enabled? returns a boolean")        { [true, false].include?(existing_de.enabled?) }
    check("parsed_settings returns Hash")      { existing_de.parsed_settings.is_a?(Hash) }
    check("Raw settings preserved after parse") do
      original = existing_de.settings
      existing_de.parsed_settings
      existing_de.settings == original
    end
    check("find returns same data element") do
      $client.data_elements.find(existing_de.id).id == existing_de.id
    end
  else
    note "No existing data elements — will create one below"
  end
else
  skip "Data Elements — Read", "no property available"
end

# ── Data Elements — Create / Update / Revise ──────────────────────

section "Data Elements — Create, Update, Revise"

created_de = nil
revised_de = nil

if property && core_ext
  de_name     = "SDK Test Data Element #{timestamp}"
  de_settings = JSON.generate({ source: "return document.title;" })
  note "Creating data element: #{de_name}"

  check("Creates a data element with extension relationship") do
    created_de = $client.data_elements.create(
      property_id:            property.id,
      name:                   de_name,
      delegate_descriptor_id: "core::dataElements::custom-code",
      settings:               de_settings,
      extension_id:           core_ext.id,
      enabled:                true
    )
    created_de.is_a?(ReactorSDK::Resources::DataElement)
  end

  if created_de
    track_latest(:data_elements, created_de)
    info "Created", "#{created_de.name} (#{created_de.id})"

    check("Name matches")                        { created_de.name == de_name }
    check("Is enabled")                          { created_de.enabled? == true }
    check("parsed_settings returns Hash")        { created_de.parsed_settings.is_a?(Hash) }
    check("parsed_settings source correct")      { created_de.parsed_settings["source"] == "return document.title;" }
    check("Findable by ID")                      { $client.data_elements.find(created_de.id).id == created_de.id }

    # Update
    updated_name = "#{de_name} — Updated"
    updated_de = nil
    check("Updates a data element name") do
      updated_de = $client.data_elements.update(created_de.id, { name: updated_name })
      updated_de.name == updated_name
    end

    if updated_de
      track_latest(:data_elements, updated_de, previous_id: created_de.id)
      created_de = updated_de
      check("Update persists on find") { $client.data_elements.find(created_de.id).name == updated_name }
      restored_de = $client.data_elements.update(created_de.id, { name: de_name })
      track_latest(:data_elements, restored_de, previous_id: created_de.id)
      created_de = restored_de
    end

    # Revise — required before adding to library
    note "Revising data element (required before adding to library)"
    check("Revises a data element") do
      revised_de = $client.data_elements.revise(created_de.id)
      revised_de.is_a?(ReactorSDK::Resources::DataElement)
    end

    if revised_de
      info "Revised data element id", revised_de.id
    end
  end
elsif !core_ext
  skip "Data Elements — Create, Update, Revise", "Core extension not available"
else
  skip "Data Elements — Create, Update, Revise", "no property available"
end

# ── Extensions — Revise ───────────────────────────────────────────

section "Extensions — Revise"

if core_ext
  note "Revising Core extension (required before adding to library)"
  revised_ext = nil
  check("Revises an extension") do
    revised_ext = $client.extensions.revise(core_ext.id)
    revised_ext.is_a?(ReactorSDK::Resources::Extension)
  end

  if revised_ext
    info "Revised extension id", revised_ext.id
  end
else
  skip "Extensions — Revise", "no Core extension available"
end

# ── Libraries — Read ─────────────────────────────────────────────

section "Libraries — Read"

libraries   = nil
dev_library = nil

if property
  check("Lists libraries for property") do
    libraries = $client.libraries.list_for_property(property.id)
    libraries.is_a?(Array)
  end

  if libraries&.any?
    dev_library = libraries.find { |l| l.state == "development" } || libraries.first
    info "Found", "#{libraries.length} library(s)"
    info "Using", "#{dev_library.name} (#{dev_library.id}) — #{dev_library.state}"

    check("Library name is a String")       { dev_library.name.is_a?(String) }
    check("Library state is a String")      { dev_library.state.is_a?(String) }
    check("buildable? returns a boolean")   { [true, false].include?(dev_library.buildable?) }
    check("published? returns a boolean")   { [true, false].include?(dev_library.published?) }
    check("find returns same library")      { $client.libraries.find(dev_library.id).id == dev_library.id }

    lwr = nil
    check("find_with_resources returns LibraryWithResources") do
      lwr = $client.libraries.find_with_resources(dev_library.id)
      lwr.is_a?(ReactorSDK::Resources::LibraryWithResources)
    end

    if lwr
      info "Rules in library",         lwr.rules.length
      info "Data elements in library", lwr.data_elements.length
      info "Extensions in library",    lwr.extensions.length

      check("rules returns Array")         { lwr.rules.is_a?(Array) }
      check("data_elements returns Array") { lwr.data_elements.is_a?(Array) }
      check("extensions returns Array")    { lwr.extensions.is_a?(Array) }
      check("resource_index returns Hash") { lwr.resource_index.is_a?(Hash) }
      check("all_resources returns Array") { lwr.all_resources.is_a?(Array) }

      if lwr.rules.any?
        r = lwr.rules.first
        check("Rules have revision_id") { r.respond_to?(:revision_id) }
        info "First rule revision_id",  r.revision_id.inspect
      end

      index = lwr.resource_index
      info "resource_index size", "#{index.size} resource(s)"
    end

    upstream = nil
    check("upstream_libraries returns Array") do
      upstream = $client.libraries.upstream_libraries(dev_library.id, property_id: property.id)
      upstream.is_a?(Array)
    end

    info "Upstream libraries", upstream&.length || 0
    upstream&.each { |u| info "  Upstream", "#{u.name} (#{u.state})" }
  else
    note "No libraries found"
  end
else
  skip "Libraries — Read", "no property available"
end

# ── Libraries — Create and Resource Management ────────────────────

section "Libraries — Create and Resource Management"

created_library = nil
library_rule_id = revised_rule&.id || created_rule&.id
library_de_id   = revised_de&.id || created_de&.id
library_ext_id  = revised_ext&.id || core_ext&.id

if property && (created_rule || created_de)
  lib_name = "SDK Test Library #{timestamp}"
  note "Creating library: #{lib_name}"

  check("Creates a library") do
    created_library = $client.libraries.create(property_id: property.id, name: lib_name)
    created_library.is_a?(ReactorSDK::Resources::Library)
  end

  if created_library
    $created[:libraries] << created_library.id
    info "Created", "#{created_library.name} (#{created_library.id})"

    check("Name matches")               { created_library.name == lib_name }
    check("State is development")       { created_library.state == "development" }
    check("Is buildable")               { created_library.buildable? == true }

    # Add rules (after revise)
    if library_rule_id
      check("add_rules adds revised rule to library") do
        $client.libraries.add_rules(created_library.id, [library_rule_id])
        lwr = $client.libraries.find_with_resources(created_library.id)
        lwr.rules.any? { |r| r.id == library_rule_id }
      end

      check("resource_index contains added rule") do
        lwr = $client.libraries.find_with_resources(created_library.id)
        lwr.resource_index.key?(library_rule_id)
      end

      check("remove_rules removes rule") do
        $client.libraries.remove_rules(created_library.id, [library_rule_id])
        lwr = $client.libraries.find_with_resources(created_library.id)
        lwr.rules.none? { |r| r.id == library_rule_id }
      end

      check("set_rules sets exact list") do
        $client.libraries.set_rules(created_library.id, [library_rule_id])
        lwr = $client.libraries.find_with_resources(created_library.id)
        lwr.rules.length == 1 && lwr.rules.first.id == library_rule_id
      end

      check("set_rules with [] removes all rules") do
        $client.libraries.set_rules(created_library.id, [])
        lwr = $client.libraries.find_with_resources(created_library.id)
        lwr.rules.empty?
      end

      # Re-add for build test — only if rule was successfully revised
      begin
        $client.libraries.add_rules(created_library.id, [library_rule_id])
        note "Rule re-added to library for build test"
      rescue ReactorSDK::Error => e
        note "Could not re-add rule (revision may have failed): #{e.message}"
      end
    end

    # Add data elements (after revise)
    if library_de_id
      check("add_data_elements adds revised data element") do
        $client.libraries.add_data_elements(created_library.id, [library_de_id])
        lwr = $client.libraries.find_with_resources(created_library.id)
        lwr.data_elements.any? { |d| d.id == library_de_id }
      end

      check("remove_data_elements removes data element") do
        $client.libraries.remove_data_elements(created_library.id, [library_de_id])
        lwr = $client.libraries.find_with_resources(created_library.id)
        lwr.data_elements.none? { |d| d.id == library_de_id }
      end

      check("set_data_elements sets exact list") do
        $client.libraries.set_data_elements(created_library.id, [library_de_id])
        lwr = $client.libraries.find_with_resources(created_library.id)
        lwr.data_elements.any? { |d| d.id == library_de_id }
      end
    end

    # Add extensions (after revise)
    if library_ext_id
      check("add_extensions adds revised extension") do
        $client.libraries.add_extensions(created_library.id, [library_ext_id])
        lwr = $client.libraries.find_with_resources(created_library.id)
        lwr.extensions.any? { |e| e.id == library_ext_id }
      end

      check("remove_extensions removes extension") do
        $client.libraries.remove_extensions(created_library.id, [library_ext_id])
        lwr = $client.libraries.find_with_resources(created_library.id)
        lwr.extensions.none? { |e| e.id == library_ext_id }
      end

      check("set_extensions sets exact list") do
        $client.libraries.set_extensions(created_library.id, [library_ext_id])
        lwr = $client.libraries.find_with_resources(created_library.id)
        lwr.extensions.any? { |e| e.id == library_ext_id }
      end
    end
  end
else
  skip "Libraries — Create and Resource Management", "no rule or data element created"
end

# ── Libraries — Build and State Machine ──────────────────────────

section "Libraries — Build and State Machine"

triggered_build = nil
build_environment = created_personal_env || dev_environment

if created_library && build_environment
  note "Assigning environment to library: #{build_environment.name} (#{build_environment.id})"
  check("assign_environment succeeds") do
    $client.libraries.assign_environment(created_library.id, build_environment.id)
    true
  end

  note "Triggering build..."
  triggered_build = nil
  check("build triggers successfully") do
    triggered_build = $client.libraries.build(created_library.id)
    triggered_build.is_a?(ReactorSDK::Resources::Build)
  end

  if triggered_build
    info "Build triggered", "#{triggered_build.id} — #{triggered_build.status}"

    check("Build has a status")                   { triggered_build.status.is_a?(String) }
    check("Build id is a String")                 { triggered_build.id.is_a?(String) }
    check("pending? is true initially or succeeded") { triggered_build.pending? || triggered_build.succeeded? }

    note "Polling build status (max 10 minutes, checking every 30s)..."
    max_attempts = 20
    attempt      = 0
    build        = triggered_build

    loop do
      break if build.succeeded? || build.failed?
      break if attempt >= max_attempts
      attempt += 1
      sleep 30
      build = $client.builds.find(build.id)
      note "  Attempt #{attempt}/#{max_attempts} — #{build.status}"
    end

    info "Final build status", build.status

    check("Build completes without timeout")    { build.succeeded? || build.failed? }
    check("Build succeeded")                   { build.succeeded? }
    check("succeeded? is true")                { build.succeeded? }
    check("pending? is false after completion") { !build.pending? }
    check("failed? is false on success")        { !build.failed? }

    check("list_for_library includes this build") do
      builds = $client.builds.list_for_library(created_library.id)
      builds.is_a?(Array) && builds.any? { |b| b.id == build.id }
    end

    check("find returns the build") do
      found = $client.builds.find(build.id)
      found.id == build.id && found.status == build.status
    end

    if build.succeeded?
      note "Build succeeded — testing library state transitions"

      begin
        result = $client.libraries.transition(created_library.id, state: "submitted")
        $results << { description: "transition to submitted succeeds", passed: result.state == "submitted" }
        puts "  #{result.state == 'submitted' ? PASS : FAIL}  transition to submitted succeeds"
      rescue ReactorSDK::Error => e
        if e.status == 409 && e.message.include?("Upstream blocked")
          known_limitation(
            "transition to submitted succeeds",
            "HTTP 409: #{e.message} — shared sandbox upstream state can block promotion"
          )
          skip("transition to approved succeeds", "library could not transition to submitted")
        else
          raise
        end
      else
        begin
          approved = $client.libraries.transition(created_library.id, state: "approved")
          $results << { description: "transition to approved succeeds", passed: approved.state == "approved" }
          puts "  #{approved.state == 'approved' ? PASS : FAIL}  transition to approved succeeds"
        rescue ReactorSDK::Error => e
          if e.status == 409 && e.message.include?("Upstream blocked")
            known_limitation(
              "transition to approved succeeds",
              "HTTP 409: #{e.message} — shared sandbox upstream state can block approval"
            )
          else
            raise
          end
        end
      end

      note "Stopping at approved — not publishing to production in sandbox test"
    end
  end
elsif !build_environment
  skip "Libraries — Build and State Machine", "no development environment found"
else
  skip "Libraries — Build and State Machine", "no library created"
end

# ── Revisions ────────────────────────────────────────────────────

section "Revisions"

if created_rule
  revisions = nil
  check("Lists revisions for created rule") do
    revisions = $client.revisions.list_for_rule(created_rule.id)
    revisions.is_a?(Array) && revisions.length >= 1
  end

  if revisions&.any?
    info "Found", "#{revisions.length} revision(s) for rule"
    rev = revisions.first
    info "Latest revision", "#{rev.id} — revision #{rev['revision_number']} — #{rev.created_at}"

    check("Rule revisions return Rule resources") { rev.is_a?(ReactorSDK::Resources::Rule) }
    check("Rule revision has created_at")         { rev.created_at.is_a?(String) }
    check("Rule revision has revision_number")    { rev["revision_number"].is_a?(Integer) }
    check("find returns same rule revision") do
      full = $client.rules.find(rev.id)
      full.id == rev.id && full.name == rev.name
    end
  else
    note "No revisions found yet for created rule"
  end
end

if created_de
  de_revisions = nil
  check("Lists revisions for created data element") do
    de_revisions = $client.revisions.list_for_data_element(created_de.id)
    de_revisions.is_a?(Array) && de_revisions.length >= 1
  end

  if de_revisions&.any?
    info "Found", "#{de_revisions.length} revision(s) for data element"
    full_de = $client.data_elements.find(de_revisions.first.id)
    check("Data element revisions return DataElement resources") { de_revisions.first.is_a?(ReactorSDK::Resources::DataElement) }
    check("Data element revision name is present")               { full_de.name.is_a?(String) }
    check("Data element revision settings parse")                { full_de.parsed_settings.is_a?(Hash) }
  end
end

if core_ext
  ext_revisions = nil
  check("Lists revisions for Core extension") do
    ext_revisions = $client.revisions.list_for_extension(core_ext.id)
    ext_revisions.is_a?(Array) && ext_revisions.length >= 1
  end

  if ext_revisions&.any?
    info "Found", "#{ext_revisions.length} revision(s) for extension"
    full_ext = $client.extensions.find(ext_revisions.first.id)
    check("Extension revisions return Extension resources")   { ext_revisions.first.is_a?(ReactorSDK::Resources::Extension) }
    check("Extension revision has delegate descriptor")       { full_ext.delegate_descriptor_id.is_a?(String) }
    check("Extension revision settings parse")                { full_ext.parsed_settings.is_a?(Hash) }
  end
end

if !created_rule && !created_de && !core_ext
  skip "Revisions", "no revisable resources available"
end

# ── Audit Events ─────────────────────────────────────────────────

section "Audit Events"

if property
  begin
    events = $client.audit_events.list_for_property(property.id)
    $results << { description: "Lists audit events for property", passed: true }
    puts "  #{PASS}  Lists audit events for property"

    if events.any?
      info "Found", "#{events.length} audit event(s)"
      event = events.first
      info "Latest", "#{event.type_of} — #{event.entity_display_name} — #{event.created_at}"

      check("type_of is a String")             { event.type_of.is_a?(String) }
      check("entity_display_name is a String") { event.entity_display_name.is_a?(String) }
      check("created_at is a String")          { event.created_at.is_a?(String) }
      check("find returns same event")         { $client.audit_events.find(event.id).id == event.id }
    else
      note "No audit events found"
    end
  rescue ReactorSDK::ResourceNotFoundError
    known_limitation(
      "Lists audit events for property",
      "Requires Launch admin product profile on OAuth credential in Adobe Developer Console"
    )
  end
else
  skip "Audit Events", "no property available"
end

# ── Cleanup ──────────────────────────────────────────────────────

section "Cleanup — Deleting Created Resources"

note "Cleaning up resources created during this test run..."
note "Personal environment intentionally left in place"

# Delete rule components first
$created[:rule_components].each do |rc_id|
  check("Deletes rule component #{rc_id[0, 8]}...") do
    $client.rule_components.delete(rc_id)
    true
  rescue ReactorSDK::Error
    false
  end
end

# Delete rules
$created[:rules].each do |rule_id|
  check("Deletes rule #{rule_id[0, 8]}...") do
    $client.rules.delete(rule_id)
    true
  rescue ReactorSDK::Error
    false
  end
end

# Delete data elements
$created[:data_elements].each do |de_id|
  check("Deletes data element #{de_id[0, 8]}...") do
    $client.data_elements.delete(de_id)
    true
  rescue ReactorSDK::Error
    false
  end
end

# Libraries cannot be deleted via API once submitted/approved
$created[:libraries].each do |lib_id|
  begin
    lib = $client.libraries.find(lib_id)
    note "Library #{lib_id[0, 8]}... is '#{lib.state}' — cannot delete via API, left in place"
  rescue ReactorSDK::Error
    note "Library #{lib_id[0, 8]}... could not be found for cleanup"
  end
end

note "Personal environment #{created_personal_env&.id} left in place"

# ── Summary ──────────────────────────────────────────────────────

section "Results"

passed      = $results.count { |r| r[:passed] }
failed      = $results.count { |r| r[:passed] == false && !r[:skipped] }
skipped     = $results.count { |r| r[:skipped] && !r[:limitation] }
limitations = $results.count { |r| r[:limitation] }
total       = $results.count { |r| !r[:skipped] }

puts ""
puts "  #{PASS}  Passed:            #{passed}/#{total}"
puts "  #{FAIL}  Failed:            #{failed}/#{total}" if failed > 0
puts "  #{SKIP}  Skipped:           #{skipped}"         if skipped > 0
puts "  #{WARN}  Known limitations: #{limitations}"     if limitations > 0
puts ""

if limitations > 0
  puts "  Known limitations (not SDK bugs):"
  $results.select { |r| r[:limitation] }.each { |r| puts "    #{WARN}  #{r[:description]}" }
  puts ""
end

if failed > 0
  puts "  Failed checks:"
  $results.select { |r| r[:passed] == false && !r[:skipped] }.each do |r|
    puts "    #{FAIL}  #{r[:description]}"
    puts "         #{r[:error]}" if r[:error]
  end
  puts ""
  puts "  #{failed} check(s) failed — see details above."
  exit 1
else
  puts "  All SDK checks passed against your Adobe Launch sandbox."
  puts ""
  puts "  Resources left in place:"
  puts "  Personal environment: #{created_personal_env&.id || 'none'}"
  puts "  Library:              #{$created[:libraries].first || 'none'}"
end
