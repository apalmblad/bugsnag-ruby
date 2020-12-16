if ENV['GEMSETS'] and ENV['GEMSETS'].include? "coverage"
  require 'simplecov'
  require 'coveralls'

  SimpleCov.formatter = Coveralls::SimpleCov::Formatter
  SimpleCov.start do
    add_filter 'spec'
  end
end

require 'bugsnag'

require 'tmpdir'
require 'webmock/rspec'
require 'rspec/expectations'
require 'rspec/mocks'

class BugsnagTestException < RuntimeError
  attr_accessor :skip_bugsnag
end

def get_event_from_payload(payload)
  expect(payload["events"].size).to eq(1)
  payload["events"].first
end

def get_exception_from_payload(payload)
  event = get_event_from_payload(payload)
  expect(event["exceptions"].size).to eq(1)
  event["exceptions"].last
end

def get_code_from_payload(payload, index = 0)
  exception = get_exception_from_payload(payload)

  expect(exception["stacktrace"].size).to be > index

  exception["stacktrace"][index]["code"]
end

def notify_test_exception(*args)
  Bugsnag.notify(RuntimeError.new("test message"), *args)
end

def ruby_version_greater_equal?(target_version)
  Gem::Version.new(RUBY_VERSION) >= Gem::Version.new(target_version)
end

RSpec.configure do |config|
  config.order = "random"
  config.example_status_persistence_file_path = "#{Dir.tmpdir}/rspec_status"

  config.before(:each) do
    WebMock.stub_request(:post, "https://notify.bugsnag.com/")
    WebMock.stub_request(:post, "https://sessions.bugsnag.com/")

    Bugsnag.instance_variable_set(:@configuration, Bugsnag::Configuration.new)
    Bugsnag.instance_variable_set(:@session_tracker, Bugsnag::SessionTracker.new)
    Bugsnag.instance_variable_set(:@cleaner, Bugsnag::Cleaner.new(Bugsnag.configuration))

    Bugsnag.configure do |bugsnag|
      bugsnag.api_key = "c9d60ae4c7e70c4b6c4ebd3e8056d2b8"
      bugsnag.release_stage = "production"
      bugsnag.delivery_method = :synchronous
      # silence logger in tests
      bugsnag.logger = Logger.new(StringIO.new)
    end
  end

  config.after(:each) do
    Bugsnag.configuration.clear_request_data
  end
end

def have_sent_sessions(&matcher)
  have_requested(:post, "https://sessions.bugsnag.com/").with do |request|
    if matcher
      matcher.call([JSON.parse(request.body), request.headers])
      true
    else
      raise "no matcher provided to have_sent_sessions (did you use { })"
    end
  end
end

def have_sent_notification(&matcher)
  have_requested(:post, "https://notify.bugsnag.com/").with do |request|
    if matcher
      matcher.call([JSON.parse(request.body), request.headers])
      true
    else
      raise "no matcher provided to have_sent_notification (did you use { })"
    end
  end
end
