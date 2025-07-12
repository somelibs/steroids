module Steroids
  module Support
    module ErrorMethods
      extend ActiveSupport::Concern

      # --------------------------------------------------------------------------------------------
      # Instance methods
      # --------------------------------------------------------------------------------------------

      class RuntimeErrors
        attr_reader :errors
        delegate :any?, to: :errors

        def initialize(concern = [])
          @concern = concern
          @errors = []
        end

        def add(message, exception = nil)
          nil.tap do
            @errors << {
              message: message.typed!(String),
              exception: exception
            }
          end
        end

        def full_messages
          @errors.map do |error|
            error[:message]
          end.join("\n")
        end

        alias_method :full_message, :full_messages

        alias_method :<<, :add
      end

      # --------------------------------------------------------------------------------------------
      # Instance methods
      # --------------------------------------------------------------------------------------------

      included do
        def errors
          @errors ||= RuntimeErrors.new(self)
        end

        def any_errors?
          errors.any?
        end
      end
    end
  end
end
