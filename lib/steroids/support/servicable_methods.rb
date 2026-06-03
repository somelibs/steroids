module Steroids
  module Support
    module ServicableMethods
      extend ActiveSupport::Concern

      included do
        def noticable_binding
          proc do |concern|
            if respond_to?(:noticable) && concern.respond_to?(:noticable)
              noticable.merge(concern.noticable)
            end
          end
        end

        def service_context_for(options)
          respond_to?(:context) ? context.merge(options).symbolize_keys : options
        end
      end

      class_methods do
        # Declares a helper method that dispatches to a Steroids service.
        #
        #   service :sync_price, class_name: "Prices::SyncPriceService"
        #   service :sync_bundles, class_name: "Bundles::SyncBundlesService", async: true
        #
        # The block form `do |service, flash_key:|` works in both sync and async
        # mode. In sync mode, the block fires after the service finishes — so
        # `service.notice` reflects success or errors from the actual run. In
        # async mode, the block fires immediately after enqueue with a fresh
        # service instance carrying only the class-declared `success_notice` —
        # the real work happens later in the worker.
        def service(service_name, class_name:, async: false, **class_options)
          define_method service_name do |*args, **options, &block|
            service_options = service_context_for(options)
            service_class = Object.const_get(class_name)
            merged_options = { **class_options, **service_options }

            if async
              job = service_class.call_async(*args, **merged_options)
              if block
                # Build a fresh, un-run instance just to read its `success_notice` so the
                # controller block can do `redirect_to ..., flash_key => service.notice`
                # without caring whether the dispatch was sync or async. Flip the
                # noticable's dispatch_mode to `:async` so the resolver picks the
                # async branch of a Hash-form `success_notice` (or appends the
                # " (async)" suffix to a plain String).
                preview = service_class.new(*args, **merged_options)
                preview.noticable.dispatch_mode = :async
                block.apply(
                  preview, job,
                  noticable: preview.noticable,
                  flash_key: preview.noticable.flash_key
                )
              else
                job
              end
            else
              service_block = block.present? ? block : noticable_binding
              service_class.call(*args, **merged_options, &service_block)
            end
          end
        end
      end
    end
  end
end
