# ar-extensions — Ruby core extensions

All files in `lib/steroids/extensions/`. Loaded explicitly at gem boot by `Steroids::Loader#load_extensions!` (see [[ar-overview]]).

Each extension `include`s itself directly into the core class at the bottom of its file:

```ruby
Object.include(Steroids::Extensions::ObjectExtension)
Hash.include(Steroids::Extensions::HashExtension)
Array.include(Steroids::Extensions::ArrayExtension)
Method.include(Steroids::Extensions::MethodExtension)
Proc.include(Steroids::Extensions::ProcExtension)       # which itself includes MethodExtension
Class.include(Steroids::Extensions::ClassExtension)
Module.include(Steroids::Extensions::ModuleExtension)
```

## Object

| Method | Behavior |
|--------|----------|
| `instance_apply(*args, **opts, &block)` | `instance_exec`s the block, arity-matching args/opts to its signature |
| `send_apply(method_name, *args, **opts, &block)` | `send` with arity-matching; returns `nil` if not responded to |
| `send_apply!(method_name, …)` | Same but returns a `NoMethodError` instance (not raised) on miss |
| `try_method(name)` | Returns `self.method(name)` if responded to (including private), else `nil` |
| `typed(klass)` | `self` if `instance_of?(klass)` or self == `nil`, else `nil` |
| `typed!(klass)` | Same but raises `TypeError` instead of returning `nil` |
| `boolean?` | true iff `self == true || self == false` |
| `ifnil(default)` | `nil? ? default : self` |
| `marshallable?` | `!!Marshal.dump(self)` rescued |
| `serializable?(include_object=true)` | Recursive check (Hash/Array/primitives/`as_json`) |
| `deep_serialize(include_object=true)` | Recursive `as_json`/`to_h` walk; raises if not serializable |
| `freeze` (override) | Materializes `self.class.steroids_attributes_set` before delegating to super |

`Object#send_apply` is the workhorse used throughout `Services::Base` for `before_process` / `after_process` callbacks — it tolerates callbacks declared with no args, with `outcome`, with kwargs, etc.

## Hash

| Method | Behavior |
|--------|----------|
| `fetch_any(*keys)` | Returns the value for the first key that exists in the hash |

## Array

| Method | Behavior |
|--------|----------|
| `cast(value, indifferent_access=false)` | Returns the matching element or raises `ArrayExtension::ElementNotFound` |
| `find_map(&block)` | Like `each`, but returns the first non-nil/non-false block result |

`ElementNotFound < StandardError`. Used by `NoticableCollection`'s `NOTICABLE_TYPES.cast(:errors)` and `NoticableRuntime`'s `DISPATCH_MODES.cast(dispatch_mode)` — so a typo at construction surfaces immediately.

## Method / Proc

`Steroids::Extensions::MethodExtension` is included into `Method`, and re-included into `Proc` via `ProcExtension`. This is what powers the **arity-aware dispatch** all over the gem:

| Method | Behavior |
|--------|----------|
| `apply(*args, **opts, &block)` | `yield` with args/opts filtered to the receiver's signature |
| `dynamic_arguments_for(args, opts)` | Trims positional args to the method's least-required count; appends opts as a trailing positional if the method takes a final positional but no kwargs |
| `dynamic_options_for(opts)` | If `keyrest`, returns all opts; else filters to declared `:key`/`:keyreq` names |
| `arguments` | List of positional arg names |
| `options` | List of keyword arg names |
| `spread?` / `rest?` | true iff the method has `**` / `*` rest params |
| private `least_arguments` | Counts required positionals (handles trailing `:opt` group) |

This is why a `before_process` declared with `(outcome)` or no args both work — `send_apply` calls `method.dynamic_arguments_for(...)` to trim/pad.

## Class

The most consequential extension. Powers `Steroids::Types`-style `attribute` declarations:

| Method | Behavior |
|--------|----------|
| `attribute(name, default:, type:, allow_nil:)` | Defines a typed reader+writer. Reader lazily sets `@name` to `default` (type-checked) the first time it's read; writer enforces the type via `typed!`. Tracks names in `steroids_attributes_set` |
| `runtime_methods(include_modules=true)` | Class methods minus `Object`'s |
| `runtime_instance_methods(include_modules=true)` | Instance methods minus `Object`'s |
| `delegate_alias(alias_name, to:, method:)` | Defines a method that forwards to `send(to).send_apply(method, …)` |
| `forward_methods_to(method_name, if:)` | Wires `respond_to_missing?` + `method_missing` to forward |
| `try_delegate(*names, to:)` | Defines `name` methods that delegate to `to` if present, else `super` |
| `proxy(instance, &block)` | Builds an anonymous proxy class that forwards everything to `instance` |
| `build_anonymous(name, parent_class, &block)` | Creates a named subclass with `define_singleton_method(:name)` returning `class_name.demodulize`. Auto-binds to `Object.create_namespace(parent_module_name)` if a namespaced name is given |

`steroids_attributes_set` is what `Object#freeze` walks before delegating — so frozen instances have all their typed attributes materialized to default values.

## Module

| Method | Behavior |
|--------|----------|
| `grundclass` | For singleton classes, finds the underlying object via `ObjectSpace.each_object`; otherwise `self` |
| `create_namespace(namespace_string)` | Idempotently creates `Foo::Bar::Baz` and returns the deepest module. Used by `Class#build_anonymous` |
| private `mixin(method_name)` | Delegates a class method as an instance method on the grundclass |
| private `mixin_alias(alias_name, method_name)` | Alias-style mixin |

## Gotchas

- These extensions **shadow** core Ruby methods that don't exist by default. If a host app defines its own `Object#typed!`, etc., Steroids will overwrite it. There is no namespacing.
- `Object#freeze` is overridden — anything frozen after touching `steroids_attributes_set` will lazily materialize those ivars first. Don't read it as a pure no-op.
- `Array#cast` raises — it's not a soft find. Use it where missing-element means programmer error.
- The `ProcExtension` is just `include MethodExtension`. Methods like `apply` on a Proc match the same arity logic as on a Method.
