module Steroids
  module Controllers
    module Methods
      extend ActiveSupport::Concern

      included do
        include RespondersHelper
        include SerializersHelper
        include Support::ServicableMethods

        def context
          # Using context is deprecated and will be removed.
          @context ||= ActiveSupport::HashWithIndifferentAccess.new
        end
      end
    end
  end
end
