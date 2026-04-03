# frozen_string_literal: true

module ReactorSDK
  module ResourceMetadata
    module_function

    def summary(resource)
      decorate!(
        {
          'id' => resource.id,
          'type' => resource.type
        },
        resource
      )
    end

    def base_payload(resource, kind:, attributes:, launch_raw:)
      decorate!(
        {
          'kind' => kind,
          'id' => resource.id,
          'attributes' => attributes,
          'launch_raw' => launch_raw
        },
        resource,
        include_position: false,
        include_revision: false
      )
    end

    def delegate_descriptor(resource)
      return '' unless resource.respond_to?(:delegate_descriptor_id)

      resource.delegate_descriptor_id.to_s
    end

    def revision_id_for(resource)
      return resource.revision_id if resource.respond_to?(:revision_id)
      return resource.relationship_id('latest_revision') if resource.respond_to?(:relationship_id)

      nil
    end

    def decorate!(payload, resource, include_position: true, include_revision: true)
      add_name(payload, resource)
      add_delegate_descriptor(payload, resource)
      add_position_fields(payload, resource) if include_position
      add_revision_id(payload, resource) if include_revision

      payload
    end

    def add_name(payload, resource)
      payload['name'] = resource.name if resource.respond_to?(:name)
    end

    def add_delegate_descriptor(payload, resource)
      return unless resource.respond_to?(:delegate_descriptor_id)

      payload['delegate_descriptor_id'] = resource.delegate_descriptor_id
    end

    def add_position_fields(payload, resource)
      payload['order'] = resource.order if resource.respond_to?(:order) && !resource.order.nil?
      payload['rule_order'] = resource.rule_order if resource.respond_to?(:rule_order) && !resource.rule_order.nil?
    end

    def add_revision_id(payload, resource)
      revision_id = revision_id_for(resource)
      payload['revision_id'] = revision_id if revision_id
    end
  end
end
