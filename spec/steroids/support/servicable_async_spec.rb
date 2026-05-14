# frozen_string_literal: true

require "spec_helper"

RSpec.describe Steroids::Support::ServicableMethods, "async: true" do
  before(:all) do
    module ServicableAsyncSpec
      class NewsletterService < Steroids::Services::Base
        success_notice sync: "Newsletter sent",
                       async: "Newsletter queued"

        def initialize(audience:)
          @audience = audience
        end

        def process
          "sent to #{@audience}"
        end
      end

      class AsyncController
        include Steroids::Support::ServicableMethods

        service :dispatch_newsletter,
                class_name: "ServicableAsyncSpec::NewsletterService",
                async: true

        attr_reader :flash_message, :flash_key

        def trigger(audience:)
          dispatch_newsletter(audience: audience) do |service, _job, **options|
            @flash_message = service.notice
            @flash_key = options[:flash_key]
          end
        end
      end
    end
  end

  before do
    @original_adapter = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :test
    ActiveJob::Base.queue_adapter.enqueued_jobs.clear
  end

  after { ActiveJob::Base.queue_adapter = @original_adapter }

  it "enqueues the service via .call_async and skips inline execution" do
    ServicableAsyncSpec::AsyncController.new.trigger(audience: "subscribers")

    jobs = ActiveJob::Base.queue_adapter.enqueued_jobs
    expect(jobs.size).to eq(1)
    expect(jobs.first[:job].name).to eq("Steroids::AsyncServiceJob")
    expect(jobs.first[:args].first["params"]["audience"]).to eq("subscribers")
  end

  it "yields a preview service with dispatch_mode=:async so notice reflects the async message" do
    controller = ServicableAsyncSpec::AsyncController.new
    controller.trigger(audience: "subscribers")

    expect(controller.flash_message).to eq("Newsletter queued")
    expect(controller.flash_key).to eq(:notice)
  end

  it "returns the job when no block is given" do
    controller_class = Class.new do
      include Steroids::Support::ServicableMethods
      service :dispatch, class_name: "ServicableAsyncSpec::NewsletterService", async: true
    end
    job = controller_class.new.dispatch(audience: "subs")
    expect(job).to be_a(ActiveJob::Base)
  end
end
