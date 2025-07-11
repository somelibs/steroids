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
          Rails.cache.fetch("steroids/quotes") do
            begin
                YAML.load_file(path)
            rescue StandardError => e
              Rails.logger.error(e)
              quotes = ["One little bug..."]
            end
            quotes.sample
          end
        end
      end
    end
  end
end
