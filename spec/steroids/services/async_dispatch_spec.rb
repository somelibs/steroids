# frozen_string_literal: true

require "spec_helper"

RSpec.describe Steroids::Services::Base, ".call_async / .call_sync" do
  before(:all) do
    module AsyncDispatchSpec
      class MultiplyService < Steroids::Services::Base
        success_notice "Multiplied"

        attr_reader :processed

        def initialize(value:, multiplier:)
          @value = value
          @multiplier = multiplier
          @processed = false
        end

        def process
          @processed = true
          @value * @multiplier
        end
      end

      class MustBeAsyncService < Steroids::Services::Base
        async_only!

        def initialize(payload:)
          @payload = payload
        end

        def process
          @payload.upcase
        end
      end

      class CallbackService < Steroids::Services::Base
        before_process :setup
        attr_reader :setup_called

        def initialize
          @setup_called = false
        end

        def process
          "done"
        end

        private

        def setup
          @setup_called = true
        end
      end

      class HashNoticeService < Steroids::Services::Base
        success_notice sync: "Newsletter sent to all subscribers",
                       async: "Newsletter queued — subscribers notified shortly"

        def process
          :done
        end
      end

      class StringNoticeService < Steroids::Services::Base
        success_notice "Newsletter dispatched"

        def process
          :done
        end
      end

      class PartialHashNoticeService < Steroids::Services::Base
        success_notice async: "Cleanup queued"

        def process
          :done
        end
      end

      class NoNoticeService < Steroids::Services::Base
        def process
          :done
        end
      end

      class ConstructorSpyService < Steroids::Services::Base
        class << self
          attr_accessor :captured_args
        end

        def initialize(**kwargs)
          self.class.captured_args = kwargs
        end

        def process
          :ok
        end
      end

      class CallbackCounterService < Steroids::Services::Base
        before_process :bump

        class << self
          attr_accessor :runs
        end

        def initialize
          self.class.runs ||= 0
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

  let(:job_queue) { ActiveJob::Base.queue_adapter.enqueued_jobs }
  let(:original_adapter) { ActiveJob::Base.queue_adapter }

  before do
    ActiveJob::Base.queue_adapter = :test
    ActiveJob::Base.queue_adapter.enqueued_jobs.clear
  end

  after { ActiveJob::Base.queue_adapter = original_adapter }

  describe ".call" do
    it "runs process inline and returns the result" do
      expect(AsyncDispatchSpec::MultiplyService.call(value: 7, multiplier: 2)).to eq(14)
    end

    it "does not enqueue a job" do
      AsyncDispatchSpec::MultiplyService.call(value: 1, multiplier: 1)
      expect(job_queue).to be_empty
    end
  end

  describe ".call_sync" do
    it "is an alias for .call" do
      expect(AsyncDispatchSpec::MultiplyService.call_sync(value: 5, multiplier: 3)).to eq(15)
      expect(job_queue).to be_empty
    end
  end

  describe ".call_async" do
    it "enqueues Steroids::AsyncServiceJob without running inline" do
      AsyncDispatchSpec::MultiplyService.call_async(value: 3, multiplier: 4)

      expect(job_queue.size).to eq(1)
      job = job_queue.first
      expect(job[:job].name).to eq("Steroids::AsyncServiceJob")

      payload = job[:args].first
      expect(payload["class_name"]).to eq("AsyncDispatchSpec::MultiplyService")
      expect(payload["params"]["value"]).to eq(3)
      expect(payload["params"]["multiplier"]).to eq(4)
    end

    it "forwards control flags to the worker via control:" do
      AsyncDispatchSpec::CallbackService.call_async(skip_callbacks: true)
      payload = job_queue.first[:args].first
      expect(payload["control"]["skip_callbacks"]).to be true
      expect(payload["params"]).not_to have_key("skip_callbacks")
    end

    it "refuses positional arguments" do
      expect { AsyncDispatchSpec::MultiplyService.call_async("positional", value: 1, multiplier: 1) }
        .to raise_error(ArgumentError, /does not accept positional arguments/)
    end

    it "raises with a clear list when args are not serializable" do
      expect do
        AsyncDispatchSpec::MultiplyService.call_async(value: ->(x) { x }, multiplier: $stdout)
      end.to raise_error(Steroids::Services::Base::NonSerializableArgumentError) { |err|
        expect(err.message).to match(/cannot enqueue/)
        expect(err.message).to match(/value \(Proc\)/)
        expect(err.message).to match(/multiplier \(IO\)/)
      }
    end

    it "surfaces nested non-serializable values with dotted paths" do
      expect do
        AsyncDispatchSpec::MultiplyService.call_async(value: { config: { handler: ->(x) { x } } }, multiplier: 1)
      end.to raise_error(Steroids::Services::Base::NonSerializableArgumentError, /value\.config\.handler \(Proc\)/)
    end

    it "accepts serializable primitives without raising" do
      expect { AsyncDispatchSpec::MultiplyService.call_async(value: 42, multiplier: 2) }.not_to raise_error
      expect { AsyncDispatchSpec::MultiplyService.call_async(value: "string", multiplier: :symbol) }.not_to raise_error
    end
  end

  describe "async_only!" do
    it "raises AsyncOnlyError on .call" do
      expect { AsyncDispatchSpec::MustBeAsyncService.call(payload: "hello") }
        .to raise_error(Steroids::Services::Base::AsyncOnlyError) { |err|
          expect(err.message).to match(/marked `async_only!`/)
          expect(err.message).to match(/use `.*MustBeAsyncService.call_async`/)
        }
    end

    it "raises AsyncOnlyError on .call_sync" do
      expect { AsyncDispatchSpec::MustBeAsyncService.call_sync(payload: "hello") }
        .to raise_error(Steroids::Services::Base::AsyncOnlyError)
    end

    it "enqueues via .call_async" do
      AsyncDispatchSpec::MustBeAsyncService.call_async(payload: "hello")
      expect(job_queue.size).to eq(1)
    end

    it "reports the macro state" do
      expect(AsyncDispatchSpec::MustBeAsyncService).to be_async_only
      expect(AsyncDispatchSpec::MultiplyService).not_to be_async_only
    end
  end

  describe "success_notice resolution" do
    it "resolves Hash notice per dispatch_mode" do
      sync = AsyncDispatchSpec::HashNoticeService.new
      expect(sync.notice).to eq("Newsletter sent to all subscribers")

      async = AsyncDispatchSpec::HashNoticeService.new
      async.noticable.dispatch_mode = :async
      expect(async.notice).to eq("Newsletter queued — subscribers notified shortly")
    end

    it "appends ' (async)' to a plain String in async mode" do
      sync = AsyncDispatchSpec::StringNoticeService.new
      expect(sync.notice).to eq("Newsletter dispatched")

      async = AsyncDispatchSpec::StringNoticeService.new
      async.noticable.dispatch_mode = :async
      expect(async.notice).to eq("Newsletter dispatched (async)")
    end

    it "falls back to a per-mode generic for the missing key" do
      sync = AsyncDispatchSpec::PartialHashNoticeService.new
      expect(sync.notice).to eq("Partial hash notice service succeeded")

      async = AsyncDispatchSpec::PartialHashNoticeService.new
      async.noticable.dispatch_mode = :async
      expect(async.notice).to eq("Cleanup queued")
    end

    it "uses per-mode defaults when no success_notice is declared" do
      sync = AsyncDispatchSpec::NoNoticeService.new
      expect(sync.notice).to eq("No notice service succeeded")

      async = AsyncDispatchSpec::NoNoticeService.new
      async.noticable.dispatch_mode = :async
      expect(async.notice).to eq("Queued for background processing.")
    end
  end

  describe "Steroids::AsyncServiceJob worker round-trip" do
    it "re-instantiates and runs the service from the payload" do
      AsyncDispatchSpec::ConstructorSpyService.captured_args = nil

      Steroids::AsyncServiceJob.perform_now(
        class_name: "AsyncDispatchSpec::ConstructorSpyService",
        params: { value: 6, multiplier: 7 }
      )

      expect(AsyncDispatchSpec::ConstructorSpyService.captured_args).to eq(value: 6, multiplier: 7)
    end

    it "honours skip_callbacks: true via control:" do
      AsyncDispatchSpec::CallbackCounterService.runs = 0

      Steroids::AsyncServiceJob.perform_now(
        class_name: "AsyncDispatchSpec::CallbackCounterService",
        params: {},
        control: { skip_callbacks: true }
      )
      expect(AsyncDispatchSpec::CallbackCounterService.runs).to eq(0)

      Steroids::AsyncServiceJob.perform_now(
        class_name: "AsyncDispatchSpec::CallbackCounterService",
        params: {}
      )
      expect(AsyncDispatchSpec::CallbackCounterService.runs).to eq(1)
    end
  end
end
