# frozen_string_literal: true

require "spec_helper"

RSpec.describe Steroids::Services::Base, "control flags" do
  before(:all) do
    module OptionSplitSpec
      class ForceableService < Steroids::Services::Base
        def initialize(**opts)
          @opts = opts
        end

        def process
          drop!("Should stop here")
          "continued"
        end
      end

      class CallbackCounterService < Steroids::Services::Base
        before_process :bump

        class << self
          attr_accessor :runs
        end

        self.runs = 0

        def initialize
          # no-op
        end

        def process
          :ok
        end

        private

        def bump
          self.class.runs += 1
        end
      end
    end
  end

  describe "force: true" do
    it "lets the process method continue past drop!" do
      expect(OptionSplitSpec::ForceableService.call(force: true)).to eq("continued")
    end
  end

  describe "skip_callbacks: true" do
    it "skips before/after callbacks" do
      OptionSplitSpec::CallbackCounterService.runs = 0
      OptionSplitSpec::CallbackCounterService.call(skip_callbacks: true)
      expect(OptionSplitSpec::CallbackCounterService.runs).to eq(0)

      OptionSplitSpec::CallbackCounterService.call
      expect(OptionSplitSpec::CallbackCounterService.runs).to eq(1)
    end
  end
end
