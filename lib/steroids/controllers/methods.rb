module Steroids
  module Controllers
    module Methods
      extend ActiveSupport::Concern

      included do
        include RespondersHelper
        include SerializersHelper
        include Support::ServicableMethods

        def context
          Rails.logger.warn('Using context is deprecated and will be removed.') unless Rails.env.production?
          @context ||= ActiveSupport::HashWithIndifferentAccess.new
        end
      end
    end
  end
end
