module Steroids
  module Controllers
    module RespondersHelper
      extend ActiveSupport::Concern

      included do
        protected

        def respond_with(*resources, &block)
          resource = resources.first
          respond_to do | format |
            format.json {
              options = resources.extract_options!
              options = __parse_options(resource, options)
              scoped_data = __apply_scopes(resource, options)
              paginated_data = __apply_pagination(scoped_data, options)
              return __response(paginated_data, options)
            }
            format.any {
              return defined?(super) ? super(*resources, &block) : resource
            }
          end
        end

        def context
          Rails.logger.warn('Using context is deprecated and will be removed.') unless Rails.env.production?
          @context ||= ActiveSupport::HashWithIndifferentAccess.new
        end

        private

        def __parse_options(data, options)
          options[:serializer] ||= self.class.serializer
          options[:params] = params
          if data.is_a?(Array) || data.is_a?(ActiveRecord::Relation)
            options[:each_serializer] ||= options[:serializer]
            options[:serializer] = ::CollectionSerializer
          end
          options
        end

        def __apply_scopes(data, options)
          if data.is_a?(ActiveRecord::Relation)
            data = apply_scopes(data)
            if options[:scoped_only] == true && current_scopes.empty?
              return []
            end
          end
          data
        end

        def __apply_pagination(data, options)
          if data.is_a?(ActiveRecord::Relation) && options[:paginate] == true
            return data.page(params[:page] || 1)
          end
          data
        end

        def __response(data, options)
          status = options[:status]
          if data
            options = options.merge({ json: data })
            options = options.merge(@context || {})
            render(options)
          else
            status ? head(status) : raise(Steroids::Errors::NotFoundError)
          end
        end
      end
    end
  end
end
