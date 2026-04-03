# frozen_string_literal: true

module ReactorSDK
  module ReferenceExtractor
    DATA_ELEMENT_TOKEN_PATTERN = /%([^%\r\n]+)%/
    GET_VAR_PATTERN = /_satellite\.getVar\(\s*(['"])(.*?)\1\s*\)/

    module_function

    def extract_data_element_names(resource)
      names = Set.new

      collect_string_references(resource.parsed_settings, names) if resource.respond_to?(:parsed_settings)

      raw_settings = resource.respond_to?(:settings) ? resource.settings : nil
      collect_string_references(raw_settings, names) if raw_settings.is_a?(String)

      names.to_a
    end

    def collect_string_references(value, names)
      case value
      when String
        value.scan(DATA_ELEMENT_TOKEN_PATTERN) { |match| names << match.first }
        value.scan(GET_VAR_PATTERN) { |match| names << match.last }
      when Array
        value.each { |item| collect_string_references(item, names) }
      when Hash
        value.each_value { |item| collect_string_references(item, names) }
      end
    end
    private_class_method :collect_string_references
  end
end
