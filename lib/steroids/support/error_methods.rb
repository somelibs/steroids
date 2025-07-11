module Steroids
  module Support
    module ErrorMethods
      extend ActiveSupport::Concern

      included do
        def errors?
          errors.any?
        end

        def errors
          @errors ||= []
        end
      end
    end
  end
end
