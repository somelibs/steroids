module Steroids
  module Errors
    module Context
      extend ActiveSupport::Concern

      QUOTES_FILEPATH = Steroids.root_path, "misc/quotes.yml"

      included do
        protected

        def load_quotes
          path = File.join(QUOTES_FILEPATH)
        end

        def quote
          Rails.cache.fetch("steroids/quotes") do
            begin
                YAML.load_file(path)
              end
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
