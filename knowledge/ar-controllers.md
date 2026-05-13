# ar-controllers — Controller integration

Sources: `lib/steroids/controllers/methods.rb`, `responders_helper.rb`, `serializers_helper.rb`; `lib/steroids/support/servicable_methods.rb` (the `service` macro itself).

## What you mix in

```ruby
class ApplicationController < ActionController::API
  include Steroids::Controllers::Methods
end
```

`Steroids::Controllers::Methods` is a `Concern` that pulls in three other concerns at once:

- `RespondersHelper` — `respond_with` JSON renderer with serializers + pagination + scopes
- `SerializersHelper` — `default_serializer` class macro
- `Support::ServicableMethods` — the `service :name, class_name:, async:` macro

Plus a `def context` that returns an `ActiveSupport::HashWithIndifferentAccess`. (The `context` machinery is flagged as deprecated in code comments — `# Using context is deprecated and will be removed.` — but still used by `service_context_for(options)`.)

## The `service` macro

```ruby
class OrdersController < ApplicationController
  service :create_order,  class_name: "Orders::CreateService"
  service :sync_inventory, class_name: "Inventory::SyncService", async: true
end
```

For each invocation, a method is defined:

```ruby
def create_order(*args, **options, &block)
  service_options = service_context_for(options)       # merges with self.context
  service_class   = Object.const_get(class_name)
  merged_options  = { **class_options, **service_options }

  if async
    job = service_class.call_async(*args, **merged_options)
    if block
      preview = service_class.new(*args, **merged_options)
      preview.noticable.dispatch_mode = :async
      block.apply(preview, job, noticable: preview.noticable, flash_key: preview.noticable.flash_key)
    else
      job
    end
  else
    service_block = block.present? ? block : noticable_binding
    service_class.call(*args, **merged_options, &service_block)
  end
end
```

Key behaviors:

- **Sync (`async: false`)** — `.call` runs inline; if no block was given, `noticable_binding` is the fallback (it merges the called service's noticable into the controller's own, when the controller itself includes `ServicableMethods` and has a `noticable`).
- **Async (`async: true`)** — `.call_async` enqueues; if a block was given, the block fires immediately against a **preview** instance whose `dispatch_mode` is forced to `:async`. The preview is **not run** — it exists only so `service.notice` resolves the right async-branch message.

This is what makes the controller-side code symmetric:

```ruby
def create
  create_order(order_params) do |service|
    redirect_to root_path, service.flash_key => service.notice
  end
end
```

…works identically for both sync and async dispatch.

## `RespondersHelper#respond_with`

JSON-aware override:

```ruby
respond_with(@records, serializer: UserSerializer, paginate: true, scoped_only: true)
```

- Forces `options[:serializer]` to the class's `default_serializer` if unset.
- Wraps Array/Relation in `::CollectionSerializer` (not shipped by this gem — must be available in the host).
- Applies `apply_scopes` (from `has_scope` gem, when host opts in) if data is a Relation.
- Optionally paginates via `.page(params[:page] || 1)` (kaminari/will_paginate-style — also host-provided).
- Renders, or `head(status)` / raises `NotFoundError` if data is nil.

The `any` format branch delegates to `super` if defined, else returns the resource — so non-JSON formats fall through to default Rails behavior.

## `SerializersHelper`

```ruby
class UsersController < ApplicationController
  default_serializer "UserSerializer"
end
```

Just a class-level attr accessor: `@serializer`. `RespondersHelper#__parse_options` reads `self.class.serializer` to pick a default when none is passed.
