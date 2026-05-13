# ar-types-serializers — Type system & serializers

## Types

Source: `lib/steroids/types/serializable_type.rb`, `lib/steroids/types/base.rb`.

### `SerializableType`

```ruby
class Address < Steroids::Types::SerializableType
  attribute :street       # via override of attr_accessor
  attribute :city
end
```

Sits on top of `ActiveModel::Model` + `ActiveModel::Serialization`. Subclasses `MagicClass` (so it picks up `NoticableMethods` — see [[ar-noticable]]).

Key trick: it **overrides `attr_accessor`** to be an alias for `attributes(*attr)`, which both calls `native_attr_accessor` and tracks the names in `@attributes`. So every typed attribute is automatically a known field for ActiveModel serialization.

### `Types::Base`

Adds **required-attribute** enforcement on top of `SerializableType`:

```ruby
class Payment < Steroids::Types::Base
  attributes :amount, :currency
  requires :amount
  requires :currency

  def import(options, _object)
    self.amount   = options.fetch(:amount)
    self.currency = options.fetch(:currency)
  end
end

Payment.new(amount: 10)                            # raises InternalServerError listing missing :currency
Payment.new({}, true)                              # bypass required-check (ignore_required=true)
Payment.import({ amount: 10, currency: "USD" }, target_record)
```

`requires` appends to `@required_attributes`. `validate_required!` and `missing_attributes_for(payload)` are exposed on both class and instance levels. `.import(options, object)` instantiates with `ignore_required = true`, calls `instance.import(options, object)`, and wraps any exception in a `Steroids::Errors::InternalServerError`.

Use cases in the broader ecosystem are payload type objects (API request DTOs, integration payloads) — but the gem itself doesn't ship any concrete subclasses.

## Serializers

Source: `lib/steroids/serializers/base.rb`, `lib/steroids/serializers/methods.rb`.

### `Steroids::Serializers::Base`

```ruby
class UserSerializer < Steroids::Serializers::Base
  attributes :id, :name, :email
end
```

Subclass of `ActiveModel::Serializer` with `Methods` mixed in. The `Methods` concern:

- **`initialize(object, options = {})`** — sets each option as `@name` on the serializer instance, then calls `super`. Lets you reach `@scope`, `@params`, etc. inside attribute methods.
- **`serializable_hash`** — calls `super`, then **prunes `nil` values** from the resulting Hash. (So a serializer that exposes `:phone` won't emit `"phone": null` when the user has no phone.)
- **`json_key`** — hardcoded `"root"`.
- **`parse_options`** (protected) — walks `options[:params]` and coerces stringy values:
  - `"true"` → `true`
  - `"false"` → `false`
  - Integer regex `/^[-+]?[1-9]([0-9]*)?$/` → `Integer(value)`
- **`attributes(*attrs, **opts)`** class method override — supports positional-array form (`attributes [:a, :b]`) which the parent doesn't natively. Strips `:key` from opts. Tracking note: this is awaiting PRs `rails-api/active_model_serializers#2145` and `#2148`.

### `Steroids::ErrorSerializer`

`app/serializers/steroids/error_serializer.rb`. Renders a `Steroids::Errors::Base` for JSON API responses. Conditionally includes the raw `exception` attribute only when `Rails.env` is dev/test (consolidation pass from the 2026-05-11 wrapup). See [[ar-errors-observability]].
