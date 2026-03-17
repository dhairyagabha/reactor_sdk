# frozen_string_literal: true

##
# @file resources/base_resource.rb
# @description Base class for all Adobe Launch resource objects.
#
#   Provides a class-level `attribute` macro that subclasses use to declare
#   which JSON:API attributes should be exposed as first-class Ruby methods.
#
#   Instead of accessing raw hash values like:
#     property.attributes["name"]
#     property["platform"]
#
#   Subclasses declare their fields and callers use clean dot notation:
#     property.name
#     property.platform
#     property.enabled?   # boolean fields get a ? alias automatically
#
#   Usage in a subclass:
#     class Property < BaseResource
#       attribute :name
#       attribute :platform
#       attribute :enabled,  as: :boolean
#       attribute :domains,  default: []
#       attribute :created_at
#     end
#
# @domain Resources
#

module ReactorSDK
  module Resources
    class BaseResource
      # @return [String] Adobe resource ID (e.g. "PR1234abcd...")
      attr_reader :id

      # @return [String] JSON:API resource type (e.g. "rules", "properties")
      attr_reader :type

      # @return [Hash] Full raw attributes hash from the JSON:API response
      #   Available for accessing fields not declared with the attribute macro
      attr_reader :attributes

      # @return [Hash] Meta hash from the JSON:API response
      attr_reader :meta

      ##
      # Class-level macro for declaring typed attribute readers.
      # Called in subclass bodies to define which JSON:API attributes
      # are exposed as Ruby methods on the resource object.
      #
      # @param name    [Symbol]  Attribute name — must match the JSON:API field name
      # @param as      [Symbol]  Type cast — :boolean adds a ? method alias (optional)
      # @param default [Object]  Default value when the attribute is nil (optional)
      #
      # @example Declare a plain string attribute
      #   attribute :name
      #
      # @example Declare a boolean attribute (adds enabled? alias)
      #   attribute :enabled, as: :boolean
      #
      # @example Declare an array attribute with a default
      #   attribute :domains, default: []
      #
      def self.attribute(name, as: nil, default: nil)
        # Define the reader method that pulls from the attributes hash
        define_method(name) do
          value = @attributes[name.to_s]
          value.nil? ? default : value
        end

        # Boolean fields get a ? alias automatically
        # e.g. attribute :enabled, as: :boolean
        #      generates both enabled and enabled?
        define_method(:"#{name}?") { !!public_send(name) } if as == :boolean
      end

      ##
      # @param id         [String] Adobe resource ID
      # @param type       [String] JSON:API resource type
      # @param attributes [Hash]   Resource attribute values from the API response
      # @param meta       [Hash]   Optional metadata from the API response
      #
      def initialize(id:, type:, attributes: {}, meta: {})
        @id         = id
        @type       = type
        @attributes = attributes
        @meta       = meta
      end

      ##
      # Provides fallback access to any attribute by name.
      # Use this for attributes not declared with the attribute macro,
      # or for dynamic access patterns.
      #
      # @param key [String, Symbol] Attribute name
      # @return [Object, nil] Attribute value or nil if not present
      #
      def [](key)
        @attributes[key.to_s]
      end

      ##
      # Returns a readable string representation for debugging.
      # Subclasses override this to include their most useful fields.
      #
      # @return [String]
      #
      def inspect
        "#<#{self.class.name} id=#{@id.inspect} type=#{@type.inspect}>"
      end

      ##
      # Two resources are equal if they represent the same Adobe resource —
      # same id and same type, regardless of which attributes were loaded.
      #
      # @param other [Object] Object to compare with
      # @return [Boolean]
      #
      def ==(other)
        other.is_a?(BaseResource) &&
          other.id == id &&
          other.type == type
      end

      ##
      # Returns a plain hash representation of the resource.
      # Useful for serialisation, logging, and debugging.
      #
      # @return [Hash]
      #
      def to_h
        {
          id:         @id,
          type:       @type,
          attributes: @attributes,
          meta:       @meta
        }
      end
    end
  end
end
