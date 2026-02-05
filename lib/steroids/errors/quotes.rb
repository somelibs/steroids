module Steroids
  module Errors
    module Quotes
      extend ActiveSupport::Concern

      included do
        QUOTES_FILEPATH = "lib/resources/quotes.yml"

        protected

        def load_quotes
          File.join(Steroids.root_path, QUOTES_FILEPATH)
        end

        def quote
          quotes = Rails.cache.fetch("steroids/quotes") do
            begin
              YAML.load_file(load_quotes)
            rescue StandardError => e
              Rails.logger.error(e)
              ["One little bug..."]
            end
          end
          Array(quotes).sample
        end
      end
    end
  end
end
