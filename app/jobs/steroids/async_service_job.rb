module Steroids
  class AsyncServiceJob < ActiveJob::Base
    queue_as :default

    def perform(class_name:, params:)
      service = class_name.constantize
      instance = service.new(**params)
      instance.send(:exec_process)
    end
  end
end
