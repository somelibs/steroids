module Steroids
  class AsyncServiceJob < ApplicationJob
    queue_as Rails.application.config.active_job.queue_adapter

    def perform(class_name:, params:)
      service = class_name.constantize
      service.new(**params).call
    end
  end
end
