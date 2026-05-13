require "test_helper"

# Steroids::Types::Base layers required-attribute validation on top of
# SerializableType.
class BaseTypeTest < ActiveSupport::TestCase
  class PaymentType < Steroids::Types::Base
    attributes :amount, :currency
    requires :amount
    requires :currency

    def import(options, _object)
      self.amount   = options[:amount]
      self.currency = options[:currency]
    end
  end

  test ".new with all required attributes succeeds" do
    payment = PaymentType.new(amount: 10, currency: "USD")
    assert_equal 10, payment.amount
    assert_equal "USD", payment.currency
  end

  test ".new raises when a required attribute is missing" do
    err = assert_raises(Steroids::Errors::InternalServerError) do
      PaymentType.new(amount: 10)
    end
    assert_match(/Missing required attributes/, err.message)
    assert_match(/currency/, err.message)
  end

  test ".new raises when a required attribute is nil" do
    assert_raises(Steroids::Errors::InternalServerError) do
      PaymentType.new(amount: nil, currency: "USD")
    end
  end

  test ".new with ignore_required=true bypasses the check" do
    payment = PaymentType.new({}, true)
    assert_nil payment.amount
    assert_nil payment.currency
  end

  test "missing_attributes_for reports the unfilled keys" do
    missing = PaymentType.missing_attributes_for(amount: 5)
    assert_equal [:currency], missing
  end

  test "validate_required is true when all required attributes are present" do
    assert PaymentType.validate_required(amount: 1, currency: "EUR")
  end

  test ".import runs the user-defined import and wraps errors" do
    payment = PaymentType.import({ amount: 7, currency: "GBP" }, Object.new)
    assert_equal 7, payment.amount
    assert_equal "GBP", payment.currency
  end

  test ".import wraps a raised exception in InternalServerError" do
    failing = Class.new(Steroids::Types::Base) do
      def import(_opts, _obj) = raise("kaboom")
    end

    err = assert_raises(Steroids::Errors::InternalServerError) do
      failing.import({ anything: 1 }, Object.new)
    end
    assert_match(/Import failed/, err.message)
  end
end
