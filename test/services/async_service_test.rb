require "test_helper"

class AsyncServiceTest < ActiveSupport::TestCase
  # ------------------------------------------------------------------------------------------------
  # Fixtures
  # ------------------------------------------------------------------------------------------------

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

  # Per-mode success_notice (Hash form): different message for sync vs async.
  class HashNoticeService < Steroids::Services::Base
    success_notice sync: "Newsletter sent to all subscribers",
                   async: "Newsletter queued — subscribers notified shortly"

    def process
      :done
    end
  end

  # Plain-String success_notice: should pick up the " (async)" suffix in async mode.
  class StringNoticeService < Steroids::Services::Base
    success_notice "Newsletter dispatched"

    def process
      :done
    end
  end

  # Hash form with only one branch declared — exercises the per-mode fallback.
  class PartialHashNoticeService < Steroids::Services::Base
    success_notice async: "Cleanup queued"

    def process
      :done
    end
  end

  # No success_notice at all — exercises the all-defaults fallback.
  class NoNoticeService < Steroids::Services::Base
    def process
      :done
    end
  end

  # Captures init kwargs at construction time so the worker round-trip test can
  # assert that AsyncServiceJob#perform deserialized the params correctly.
  # Used in place of singleton_class alias_method gymnastics on a shared fixture.
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

  # Class-level counter callback — lets the worker control-flag test increment a
  # counter via a normal `before_process` callback without monkey-patching a
  # shared fixture mid-test.
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

  # ------------------------------------------------------------------------------------------------
  # Setup — capture all enqueued jobs without running them inline.
  # ------------------------------------------------------------------------------------------------

  setup do
    @original_adapter = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :test
    ActiveJob::Base.queue_adapter.enqueued_jobs.clear
  end

  teardown do
    ActiveJob::Base.queue_adapter = @original_adapter
  end

  # ------------------------------------------------------------------------------------------------
  # .call — runs inline
  # ------------------------------------------------------------------------------------------------

  test ".call runs process inline and returns the result" do
    result = MultiplyService.call(value: 7, multiplier: 2)
    assert_equal 14, result
  end

  test ".call_sync is an alias of .call" do
    result = MultiplyService.call_sync(value: 5, multiplier: 3)
    assert_equal 15, result
    assert_empty ActiveJob::Base.queue_adapter.enqueued_jobs
  end

  test ".call does NOT enqueue a job" do
    MultiplyService.call(value: 1, multiplier: 1)
    assert_empty ActiveJob::Base.queue_adapter.enqueued_jobs
  end

  # ------------------------------------------------------------------------------------------------
  # .call_async — enqueues, does not run inline
  # ------------------------------------------------------------------------------------------------

  test ".call_async enqueues Steroids::AsyncServiceJob and does NOT run inline" do
    service_instance = MultiplyService.new(value: 1, multiplier: 1)
    refute service_instance.processed

    MultiplyService.call_async(value: 3, multiplier: 4)

    jobs = ActiveJob::Base.queue_adapter.enqueued_jobs
    assert_equal 1, jobs.size
    assert_equal "Steroids::AsyncServiceJob", jobs.first[:job].name

    payload = jobs.first[:args].first
    assert_equal "AsyncServiceTest::MultiplyService", payload["class_name"]
    # ActiveJob serializes hash kwargs and decorates them with `_aj_symbol_keys`; assert on the
    # data we care about rather than the full decorated hash.
    assert_equal 3, payload["params"]["value"]
    assert_equal 4, payload["params"]["multiplier"]
  end

  test ".call_async forwards control flags (skip_callbacks, force) to the worker via control:" do
    CallbackService.call_async(skip_callbacks: true)

    payload = ActiveJob::Base.queue_adapter.enqueued_jobs.first[:args].first
    assert_equal true, payload["control"]["skip_callbacks"]
    # init opts must NOT contain control flags
    refute payload["params"].key?("skip_callbacks")
  end

  test ".call_async refuses positional arguments" do
    err = assert_raises(ArgumentError) do
      MultiplyService.call_async("positional", value: 1, multiplier: 1)
    end
    assert_match(/does not accept positional arguments/, err.message)
  end

  # ------------------------------------------------------------------------------------------------
  # Serializability check
  # ------------------------------------------------------------------------------------------------

  test ".call_async raises a clear error listing every non-serializable arg" do
    err = assert_raises(Steroids::Services::Base::NonSerializableArgumentError) do
      MultiplyService.call_async(value: ->(x) { x }, multiplier: $stdout)
    end

    assert_match(/cannot enqueue/, err.message)
    assert_match(/value \(Proc\)/, err.message)
    assert_match(/multiplier \(IO\)/, err.message)
  end

  test ".call_async surfaces nested non-serializable values with dotted paths" do
    err = assert_raises(Steroids::Services::Base::NonSerializableArgumentError) do
      MultiplyService.call_async(value: { config: { handler: ->(x) { x } } }, multiplier: 1)
    end
    assert_match(/value\.config\.handler \(Proc\)/, err.message)
  end

  test ".call_async accepts serializable primitives without raising" do
    assert_nothing_raised do
      MultiplyService.call_async(value: 42, multiplier: 2)
    end
    assert_nothing_raised do
      MultiplyService.call_async(value: "string", multiplier: :symbol)
    end
  end

  # ------------------------------------------------------------------------------------------------
  # async_only! services
  # ------------------------------------------------------------------------------------------------

  test "async_only! service raises AsyncOnlyError on .call" do
    err = assert_raises(Steroids::Services::Base::AsyncOnlyError) do
      MustBeAsyncService.call(payload: "hello")
    end
    assert_match(/marked `async_only!`/, err.message)
    assert_match(/use `.*MustBeAsyncService.call_async`/, err.message)
  end

  test "async_only! service raises AsyncOnlyError on .call_sync" do
    assert_raises(Steroids::Services::Base::AsyncOnlyError) do
      MustBeAsyncService.call_sync(payload: "hello")
    end
  end

  test "async_only! service enqueues via .call_async" do
    MustBeAsyncService.call_async(payload: "hello")
    assert_equal 1, ActiveJob::Base.queue_adapter.enqueued_jobs.size
  end

  test "async_only? reports the class macro state" do
    assert MustBeAsyncService.async_only?
    refute MultiplyService.async_only?
  end

  # ------------------------------------------------------------------------------------------------
  # success_notice mode resolution
  # ------------------------------------------------------------------------------------------------

  test "Hash success_notice resolves per dispatch_mode" do
    sync_service = HashNoticeService.new
    assert_equal "Newsletter sent to all subscribers", sync_service.notice

    async_service = HashNoticeService.new
    async_service.noticable.dispatch_mode = :async
    assert_equal "Newsletter queued — subscribers notified shortly", async_service.notice
  end

  test "String success_notice gains a ' (async)' suffix in async mode" do
    sync_service = StringNoticeService.new
    assert_equal "Newsletter dispatched", sync_service.notice

    async_service = StringNoticeService.new
    async_service.noticable.dispatch_mode = :async
    assert_equal "Newsletter dispatched (async)", async_service.notice
  end

  test "partial Hash success_notice falls back to the generic for the missing mode" do
    # `async:` declared, no `sync:` — sync dispatch should fall back to the class-name placeholder.
    sync_service = PartialHashNoticeService.new
    assert_equal "Partial hash notice service succeeded", sync_service.notice

    async_service = PartialHashNoticeService.new
    async_service.noticable.dispatch_mode = :async
    assert_equal "Cleanup queued", async_service.notice
  end

  test "missing success_notice falls back to per-mode defaults" do
    sync_service = NoNoticeService.new
    assert_equal "No notice service succeeded", sync_service.notice

    async_service = NoNoticeService.new
    async_service.noticable.dispatch_mode = :async
    assert_equal "Queued for background processing.", async_service.notice
  end

  # ------------------------------------------------------------------------------------------------
  # Worker round-trip — perform_now executes the service inline
  # ------------------------------------------------------------------------------------------------

  test "Steroids::AsyncServiceJob.perform_now re-instantiates and runs the service" do
    # The worker builds a fresh instance, so we can't observe state on the enqueuing one.
    # ConstructorSpyService captures its init kwargs into a class attribute — proving the
    # round-trip without mutating a shared fixture.
    ConstructorSpyService.captured_args = nil

    Steroids::AsyncServiceJob.perform_now(
      class_name: "AsyncServiceTest::ConstructorSpyService",
      params: { value: 6, multiplier: 7 }
    )

    assert_equal({ value: 6, multiplier: 7 }, ConstructorSpyService.captured_args)
  end

  test "AsyncServiceJob.perform_now honours skip_callbacks via control:" do
    # CallbackCounterService tracks before_process invocations on a class attribute, so
    # we can run two worker round-trips back-to-back and assert that `skip_callbacks: true`
    # suppresses the callback while the default path runs it.
    CallbackCounterService.runs = 0

    Steroids::AsyncServiceJob.perform_now(
      class_name: "AsyncServiceTest::CallbackCounterService",
      params: {},
      control: { skip_callbacks: true }
    )
    assert_equal 0, CallbackCounterService.runs

    Steroids::AsyncServiceJob.perform_now(
      class_name: "AsyncServiceTest::CallbackCounterService",
      params: {}
    )
    assert_equal 1, CallbackCounterService.runs
  end
end
