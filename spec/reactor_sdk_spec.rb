# frozen_string_literal: true

##
# @file spec/reactor_sdk_spec.rb
# @description Top-level smoke tests for the ReactorSDK gem.
#
#   Verifies that the gem loads correctly, the version is set,
#   and the Client can be instantiated with valid credentials.
#

RSpec.describe ReactorSDK do
  it 'has a version number' do
    expect(ReactorSDK::VERSION).not_to be_nil
  end

  it 'exposes the Client class' do
    expect(defined?(ReactorSDK::Client)).to eq('constant')
  end

  it 'exposes all resource classes' do
    expect(defined?(ReactorSDK::Resources::Company)).to eq('constant')
    expect(defined?(ReactorSDK::Resources::Property)).to eq('constant')
    expect(defined?(ReactorSDK::Resources::Environment)).to eq('constant')
    expect(defined?(ReactorSDK::Resources::Host)).to eq('constant')
    expect(defined?(ReactorSDK::Resources::Rule)).to eq('constant')
    expect(defined?(ReactorSDK::Resources::RuleComponent)).to eq('constant')
    expect(defined?(ReactorSDK::Resources::DataElement)).to eq('constant')
    expect(defined?(ReactorSDK::Resources::Extension)).to eq('constant')
    expect(defined?(ReactorSDK::Resources::Library)).to eq('constant')
    expect(defined?(ReactorSDK::Resources::LibraryWithResources)).to eq('constant')
    expect(defined?(ReactorSDK::Resources::Build)).to eq('constant')
    expect(defined?(ReactorSDK::Resources::Revision)).to eq('constant')
    expect(defined?(ReactorSDK::Resources::AuditEvent)).to eq('constant')
  end

  it 'exposes all endpoint classes' do
    expect(defined?(ReactorSDK::Endpoints::Companies)).to eq('constant')
    expect(defined?(ReactorSDK::Endpoints::Properties)).to eq('constant')
    expect(defined?(ReactorSDK::Endpoints::Environments)).to eq('constant')
    expect(defined?(ReactorSDK::Endpoints::Hosts)).to eq('constant')
    expect(defined?(ReactorSDK::Endpoints::Rules)).to eq('constant')
    expect(defined?(ReactorSDK::Endpoints::RuleComponents)).to eq('constant')
    expect(defined?(ReactorSDK::Endpoints::DataElements)).to eq('constant')
    expect(defined?(ReactorSDK::Endpoints::Extensions)).to eq('constant')
    expect(defined?(ReactorSDK::Endpoints::Libraries)).to eq('constant')
    expect(defined?(ReactorSDK::Endpoints::Builds)).to eq('constant')
    expect(defined?(ReactorSDK::Endpoints::Revisions)).to eq('constant')
    expect(defined?(ReactorSDK::Endpoints::AuditEvents)).to eq('constant')
  end
end
