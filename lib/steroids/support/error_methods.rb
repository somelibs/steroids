module Steroids
  module Support
    module ErrorMethods
      extend ActiveSupport::Concern

      included do
        def errors?
          errors.any?
        end

        def errors
          @errors ||= Steroids::Base::List.new
        end
      end
    end
  end
end
