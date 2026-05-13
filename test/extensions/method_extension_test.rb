require "test_helper"

# Steroids::Extensions::MethodExtension is included into ::Method (and ::Proc
# via ProcExtension). Powers arity-aware dispatch across the gem.
class MethodExtensionTest < ActiveSupport::TestCase
  class Target
    def zero_arg = "z"
    def one_arg(arg) = "1:#{arg}"
    def with_kwarg(arg, key:) = "k:#{arg}/#{key}"
    def with_keyrest(**opts) = "rest:#{opts.keys.sort.join(',')}"
    def with_rest(*args) = "splat:#{args.size}"
  end

  setup { @target = Target.new }

  # --------------------------------------------------------------------------------------
  # arguments / options / rest? / spread?
  # --------------------------------------------------------------------------------------

  test "arguments lists positional parameter names" do
    assert_equal [:arg], @target.method(:one_arg).arguments
    assert_equal [:arg], @target.method(:with_kwarg).arguments
  end

  test "options lists keyword parameter names" do
    assert_equal [:key], @target.method(:with_kwarg).options
  end

  test "spread? detects **opts (keyrest)" do
    assert @target.method(:with_keyrest).spread?
    refute @target.method(:with_kwarg).spread?
  end

  test "rest? detects *args (rest)" do
    assert @target.method(:with_rest).rest?
    refute @target.method(:one_arg).rest?
  end

  # --------------------------------------------------------------------------------------
  # apply — arity-aware
  # --------------------------------------------------------------------------------------

  test "apply trims extra positionals for fixed-arity methods" do
    assert_equal "1:hello", @target.method(:one_arg).apply("hello", "ignored")
  end

  test "apply pads positionals with kwargs for the trailing slot when needed" do
    # zero_arg takes no args; apply must not crash with kwargs
    assert_equal "z", @target.method(:zero_arg).apply(extra: 1)
  end

  test "apply passes all positionals when method has *rest" do
    assert_equal "splat:3", @target.method(:with_rest).apply(1, 2, 3)
  end

  test "apply forwards keyword args matching declared keywords only" do
    assert_equal "k:hello/world",
                 @target.method(:with_kwarg).apply("hello", key: "world", extra: "dropped")
  end

  test "apply forwards all keyword args when method has **keyrest" do
    assert_equal "rest:a,b,c", @target.method(:with_keyrest).apply(a: 1, b: 2, c: 3)
  end

  # --------------------------------------------------------------------------------------
  # Proc support (Proc.include MethodExtension via ProcExtension)
  # --------------------------------------------------------------------------------------

  test "ProcExtension exposes the same API on Procs" do
    p = ->(a, b) { "#{a}-#{b}" }
    assert_equal "x-y", p.apply("x", "y", "z") # extra trimmed
  end
end
