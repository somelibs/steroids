module Steroids
  class AsyncServiceJob < ApplicationJob
    queue_as Rails.application.config.active_job.queue_adapter

    def perform(class_name:, params:)
      service = class_name.constantize
      instance = service.new(**params)
      instance.call_worker
    end
  end
end
