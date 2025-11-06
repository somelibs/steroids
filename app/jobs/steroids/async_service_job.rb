module Steroids
  class AsyncServiceJob < ApplicationJob
    queue_as :default

    def perform(class_name:, params:)
      service = class_name.constantize
      service.new(**params).call
    end
  end
end
