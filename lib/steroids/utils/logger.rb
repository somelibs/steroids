module Steroids
  module Utils
    class Logger
      @notifier = false

      class << self
        attr_accessor :notifier

        def print(input = nil, level: nil)
          if input.is_a?(Steroids::Base::Error) && input.logged == true
            false
          else
            output = format_input(input)
            level = assert_level(input)
            Rails.logger.send(level, output)
            notify(level, output)
            true
          end
        end

        private

        def assert_level(input)
          return :info unless input.is_a?(Exception)

          if input.is_a?(Steroids::Errors::InternalServerError) || input.is_a?(Steroids::Errors::GenericError)
            :error
          elsif input.is_a?(Steroids::Base::Error)
            :warn
          else
            :error
          end
        end

        def notify(level, input)
          if @notifier.respond_to?(:call) && input.is_a?(Exception) && [:error, :warn].include?(level)
            @notifier.call(input)
          end
        end

        def format_timestamp(input)
          if input.respond_to?(:timestamp) && input.timestamp.is_a?(DateTime)
            "(at #{input.timestamp.to_time.to_s})"
          end
        end

        def format_message(input)
          [
            "\n➤ #{input.class.to_s} -- #{input.message.to_s.upcase_first}",
            input.respond_to?(:id) && "[ID: #{input.id.to_s}]",
            format_timestamp(input),
          ].compact_blank.join(" ")
        end

        def format_cause(input)
          [
            "↳ Cause: #{input.cause.class.name} -- #{input.cause_message.to_s}",
            input.cause.respond_to?(:record) && input.cause.record && "`#{input.cause.record.class.name}`"
          ].compact_blank.join(" ")
        end

        def format_backtrace(input)
          app_path = "#{Rails.root.to_s}/"
          "\n\t" + input.backtrace.map do |path|
            path.to_s.delete_prefix(app_path)
          end.join("\n\t") if input.backtrace.any?
        end

        def format_errors(input)
          record = input.respond_to?(:record) && input.record ? input.record : "Error"
          "  ↳" + input.errors.map do |error|
            "`#{record.class.name}` #{error}"
          end.join("\n  ↳") if input.errors.any?
        end

        def format_input(input)
          if input.is_a?(Exception)
            [
              format_message(input),
              assert_presence(input, :cause) && format_cause(input),
              assert_presence(input, :errors) && format_errors(input),
              assert_presence(input, :backtrace) && format_backtrace(input)
            ].compact_blank.join("\n") + "\n"
          else
            input
          end
        end

        def assert_presence(instance, key)
          instance.respond_to?(key) && instance.public_send(key)
        end
      end
    end
  end
end
