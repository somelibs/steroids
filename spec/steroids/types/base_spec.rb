# frozen_string_literal: true

require "spec_helper"

RSpec.describe Steroids::Types::Base do
  before(:all) do
    module TypesBaseSpec
      class PaymentType < Steroids::Types::Base
        attributes :amount, :currency
        requires :amount
        requires :currency

        def import(options, _object)
          self.amount   = options[:amount]
          self.currency = options[:currency]
        end
      end
    end
  end

  let(:payment_type) { TypesBaseSpec::PaymentType }

  describe ".new" do
    it "succeeds when all required attributes are provided" do
      payment = payment_type.new(amount: 10, currency: "USD")
      expect(payment.amount).to eq(10)
      expect(payment.currency).to eq("USD")
    end

    it "raises InternalServerError when a required attribute is missing" do
      expect { payment_type.new(amount: 10) }
        .to raise_error(Steroids::Errors::InternalServerError, /Missing required attributes.*currency/)
    end

    it "raises InternalServerError when a required attribute is nil" do
      expect { payment_type.new(amount: nil, currency: "USD") }
        .to raise_error(Steroids::Errors::InternalServerError)
    end

    it "bypasses the check when ignore_required is true" do
      payment = payment_type.new({}, true)
      expect(payment.amount).to be_nil
      expect(payment.currency).to be_nil
    end
  end

  describe ".missing_attributes_for" do
    it "reports the unfilled keys" do
      expect(payment_type.missing_attributes_for(amount: 5)).to eq([:currency])
    end
  end

  describe ".validate_required" do
    it "is true when all required attributes are present" do
      expect(payment_type.validate_required(amount: 1, currency: "EUR")).to be true
    end
  end

  describe ".import" do
    it "runs the user-defined import" do
      payment = payment_type.import({ amount: 7, currency: "GBP" }, Object.new)
      expect(payment.amount).to eq(7)
      expect(payment.currency).to eq("GBP")
    end

    it "wraps a raised exception in InternalServerError" do
      stub_const("TypesBaseSpec::FailingImport", Class.new(described_class) do
        def import(_opts, _obj) = raise("kaboom")
      end)

      expect { TypesBaseSpec::FailingImport.import({ anything: 1 }, Object.new) }
        .to raise_error(Steroids::Errors::InternalServerError, /Import failed/)
    end
  end
end
