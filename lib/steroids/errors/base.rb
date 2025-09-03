module Steroids
  module Errors
    class Base < StandardError
      include ActiveModel::Serialization
      include Context
      include Quotes

      OTPIONS = %i[status message errors code cause context log]

      class_attribute :default_message, default: "Oops, something went wrong (Unknown error)"
      class_attribute :default_status, default: :internal_server_error

      attr_reader :id, :message, :cause, :code, :status, :errors,
                      :record, :context, :timestamp, :logged

      def initialize(message_string = nil, **options)
        @caller = caller
        extended_options = options.select{|key|OTPIONS.include?(key)}
        splat_options = options.select{|key|!OTPIONS.include?(key)}
        define_instance_variables_for(message_string, **extended_options)
        super(**splat_options, message: message, cause: @cause)
        set_backtrace(@cause&.backtrace || backtrace_locations || caller)
        extended_options.fetch(:log, false) ? self.log! : self.quiet_log
      end

      def to_json
        Steroids::ErrorSerializer.new(self).to_json
      end

      def log!
        Steroids::Logger.print(self)
        @logged = true
      end

      def cause_message
        if cause
          reflect_on(cause, :original_message) || reflect_on(cause, :message)
        end
      end

      private

      def reflect_on(cause, key)
        logged = cause.respond_to?(:logged) && cause.logged
        cause.respond_to?(key) && logged != true ? cause.public_send(key) : nil
      end

      def quiet_log
        Steroids::Logger.print(
          "#{Rainbow("▶").magenta} #{Rainbow(self.class.name).red} -- #{Rainbow(self.message).magenta} (quiet)",
          verbosity: :concise,
          format: :raw
        )
      end
    end
  end
end
