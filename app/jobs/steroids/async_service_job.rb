module Steroids
  class AsyncServiceJob < ActiveJob::Base
    queue_as :default

    # Invoked by `Steroids::Services::Base.call_async`. Re-instantiates the service
    # from its class_name + serialized init params and runs `exec_process` inline
    # inside the worker. `control` carries the same flow flags accepted by the
    # synchronous `.call` (currently `force:` and `skip_callbacks:`).
    def perform(class_name:, params:, control: {})
      service_class = class_name.constantize
      instance = service_class.new(**params.symbolize_keys)

      control = (control || {}).symbolize_keys
      instance.instance_variable_set(:@steroids_force, !!control[:force])
      instance.instance_variable_set(:@steroids_skip_callbacks, !!control[:skip_callbacks])

      instance.send(:exec_process)
    end
  end
end
