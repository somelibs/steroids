module Steroids
  module Utils
    class Logger
      @notifier = false

      class << self
        attr_accessor :notifier

        def print(input = nil)
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
          if (input.is_a?(Steroids::Errors::InternalServerError) || input.is_a?(Steroids::Errors::GenericError))
            :error
          elsif input.is_a?(Steroids::Base::Error)
            :warn
          elsif input.is_a?(Exception)
            :error
          else
            :info
          end
        end

        def notify(level, input)
          if @notifier.respond_to?(:call) && input.is_a?(Exception) && [:error, :warn].include?(level)
            @notifier.call(input)
          end
        end

        def format_input(input)
          if input.is_a?(Exception)
            app_path = Rails.root.to_s
            output = input.class.to_s + ": " + input.message.to_s.upcase_first
            output += "\n\t" + input.backtrace.map {
                |path| path.to_s.delete_prefix(app_path)
              }.join("\n\t") if input.backtrace.present?
            output
          else
            input
          end
        end
      end
    end
  end
end
