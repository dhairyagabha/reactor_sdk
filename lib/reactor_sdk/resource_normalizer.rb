# frozen_string_literal: true

module ReactorSDK
  module ResourceNormalizer
    CUSTOM_CODE_PATTERN = /::custom-code\z/i
    ADOBE_ALLOY_PATTERN = /\Aadobe-alloy::/i
    ADOBE_ANALYTICS_PATTERN = /\Aadobe-analytics::/i

    module_function

    def normalize_resource(resource)
      configuration, status = normalize_configuration(resource)

      ReactorSDK::ResourceMetadata.base_payload(
        resource,
        kind: kind_for(resource),
        attributes: resource.attributes.except('settings'),
        launch_raw: resource.to_h
      ).merge(
        'configuration' => configuration,
        'normalization_status' => status
      )
    end

    def summary(resource)
      ReactorSDK::ResourceMetadata.summary(resource)
    end

    def to_json(payload)
      JSON.pretty_generate(payload)
    end

    def kind_for(resource)
      case resource.type
      when 'data_elements' then 'data_element'
      when 'rule_components' then 'rule_component'
      else
        resource.type.sub(/s\z/, '')
      end
    end

    def normalize_configuration(resource)
      return [nil, 'none'] unless resource.respond_to?(:settings)

      parsed = resource.respond_to?(:parsed_settings) ? resource.parsed_settings : {}
      return [nil, 'none'] if parsed.empty? && blank_settings?(resource.settings)

      normalize_delegate_configuration(
        ReactorSDK::ResourceMetadata.delegate_descriptor(resource),
        parsed,
        resource
      )
    rescue JSON::ParserError
      [resource.settings, 'raw']
    end

    def normalize_custom_code(parsed, resource)
      language = parsed['language']
      language = 'javascript' if language.nil? && resource.type == 'data_elements'

      normalized = {}
      normalized['language'] = language if language
      normalized['source'] = parsed['source'] if parsed.key?('source')

      parsed.each do |key, value|
        next if %w[language source].include?(key)

        normalized[key] = value
      end

      normalized
    end

    def blank_settings?(settings)
      settings.nil? || settings == ''
    end

    def normalize_delegate_configuration(delegate, parsed, resource)
      return [normalize_custom_code(parsed, resource), 'normalized'] if delegate.match?(CUSTOM_CODE_PATTERN)
      return [parsed, 'normalized'] if delegate.match?(ADOBE_ALLOY_PATTERN)
      return [parsed, 'normalized'] if delegate.match?(ADOBE_ANALYTICS_PATTERN)
      return [parsed, 'parsed'] unless parsed.empty?

      [resource.settings, 'raw']
    end

    private_class_method :kind_for, :normalize_configuration, :normalize_custom_code, :blank_settings?,
                         :normalize_delegate_configuration
  end
end
