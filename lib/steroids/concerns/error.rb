module Steroids
  module Concerns
    module Error
      extend ActiveSupport::Concern
      included do
        def errors?
          errors.any?
        end

        def errors
          @errors ||= Steroids::Base::List.new
        end

        class << self
          attr_accessor :errors
        end
      end
    end
  end
end
