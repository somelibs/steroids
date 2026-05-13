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
            YAML.load_file(load_quotes)
          rescue => e
            Rails.logger.error(e)
            ["One little bug..."]
          end
          Array(quotes).sample
        end
      end
    end
  end
end
