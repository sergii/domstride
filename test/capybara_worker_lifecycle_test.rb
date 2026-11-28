require "minitest/autorun"
require "tmpdir"
require "specdrive/capybara"

class CapybaraWorkerLifecycleTest < Minitest::Test
  REUSE_KEYS = %w[SPECDRIVE_REUSE_WORKER DOMSTRIDE_REUSE_WORKER SPECDRIVE_RECORD_DIR DOMSTRIDE_RECORD_DIR].freeze
  APP = lambda do |env|
    headers = { "content-type" => "text/html" }
    if env["PATH_INFO"] == "/seed"
      headers["set-cookie"] = "test_token=secret; Path=/"
    end
    cookie = env.fetch("HTTP_COOKIE", "").include?("test_token=secret") ? "present" : "absent"
    [200, headers, ["<!doctype html><html><body><p id='cookie'>#{cookie}</p><button id='target'>Target</button></body></html>"]]
  end

  def setup
    @saved_env = REUSE_KEYS.to_h { |key| [key, ENV[key]] }
    REUSE_KEYS.each { |key| ENV.delete(key) }
    @drivers = []
  end

  def teardown
    @drivers.reverse_each(&:quit)
  ensure
    @saved_env.each { |key, value| ENV[key] = value }
  end

  def driver(**options)
    Specdrive::CapybaraAdapter::Driver.new(APP, **{
      runtime: "node", engine: "jsdom31", clock: "real", assets: "off",
      websocket_url: nil, settling: "checkpoint"
    }.merge(options)).tap { |item| @drivers << item }
  end

  def test_default_reuses_process_but_resets_document_and_rack_session
    %w[jsdom jsdom31].each do |engine|
      item = driver(engine: engine)
      item.visit("/seed")
      pid = item.worker.worker_pid
      item.visit("/check")
      assert_equal "present", item.find_css("#cookie").first.all_text
      old_element = item.find_css("#target").first
      item.execute_script(<<~JS)
        localStorage.setItem("test", "secret");
        sessionStorage.setItem("test", "secret");
        window.testGlobal = "secret";
        window.setInterval(() => { window.testGlobal = "timer"; }, 100);
      JS
      assert_equal "secret", item.evaluate_script("localStorage.getItem('test')")
      assert_equal "secret", item.evaluate_script("sessionStorage.getItem('test')")
      item.reset!
      assert_equal pid, item.diagnostics.fetch(:worker_pid)
      assert_equal :auto, item.diagnostics.fetch(:reuse_worker_mode)
      assert_equal "about:blank", item.current_url
      assert_equal "", item.html
      assert_raises(Specdrive::CapybaraAdapter::StaleElement) { old_element.all_text }
      state = item.worker.dom_command("memory_state")
      assert_equal false, state.fetch("has_document")
      assert_equal 0, state.fetch("handles")
      assert_equal 0, state.fetch("pending_requests")
      assert_equal 0, state.fetch("active_fetches")
      assert_equal 0, state.fetch("error_listeners")
      item.visit("/check")
      assert_equal pid, item.worker.worker_pid
      assert_equal "absent", item.find_css("#cookie").first.all_text
      assert_nil item.evaluate_script("localStorage.getItem('test')")
      assert_nil item.evaluate_script("sessionStorage.getItem('test')")
      assert_equal "undefined", item.evaluate_script("typeof window.testGlobal")
      item.quit
    end
  end

  def test_capybara_session_reset_retains_default_worker
    Capybara.register_driver(:specdrive_lifecycle_contract) do |app|
      Specdrive::CapybaraAdapter::Driver.new(app, runtime: "node", engine: "jsdom31",
        clock: "real", assets: "off", websocket_url: nil)
    end
    session = Capybara::Session.new(:specdrive_lifecycle_contract, APP)
    @drivers << session.driver
    session.visit("/seed")
    pid = session.driver.worker.worker_pid
    session.visit("/check")
    assert session.has_css?("#cookie", text: "present")
    session.reset!
    session.visit("/check")
    assert_equal pid, session.driver.worker.worker_pid
    assert session.has_css?("#cookie", text: "absent")
  end

  def test_recording_environment_uses_isolated_worker
    Dir.mktmpdir do |directory|
      ENV["SPECDRIVE_RECORD_DIR"] = directory
      item = driver
      item.visit("/")
      refute item.diagnostics.fetch(:worker_reusable)
      item.reset!
      refute item.diagnostics.fetch(:worker_started)
      assert_raises(ArgumentError) { driver(reuse_worker: true) }
    end
  end

  def test_explicit_false_keeps_process_per_reset
    item = driver(reuse_worker: false)
    item.visit("/")
    pid = item.worker.worker_pid
    item.reset!
    refute item.diagnostics.fetch(:worker_started)
    item.visit("/")
    refute_equal pid, item.worker.worker_pid
  end

  def test_explicit_true_reuses_process
    item = driver(reuse_worker: true)
    item.visit("/")
    pid = item.worker.worker_pid
    item.reset!
    item.visit("/")
    assert_equal pid, item.worker.worker_pid
  end

  def test_keyword_and_canonical_env_precedence
    ENV["DOMSTRIDE_REUSE_WORKER"] = "1"
    ENV["SPECDRIVE_REUSE_WORKER"] = "0"
    assert_equal false, driver.diagnostics.fetch(:reuse_worker_mode)
    assert_equal true, driver(reuse_worker: true).diagnostics.fetch(:reuse_worker_mode)
    ENV.delete("SPECDRIVE_REUSE_WORKER")
    assert_equal true, driver.diagnostics.fetch(:reuse_worker_mode)
    ENV["SPECDRIVE_REUSE_WORKER"] = "auto"
    assert_equal :auto, driver.diagnostics.fetch(:reuse_worker_mode)
    ENV["SPECDRIVE_REUSE_WORKER"] = "invalid"
    assert_raises(ArgumentError) { driver }
  end

  def test_auto_does_not_reuse_incompatible_configurations
    [
      { runtime: "bun" }, { engine: "happy-dom" }, { clock: "virtual" },
      { websocket_url: "ws://example.test/cable" }
    ].each do |options|
      item = driver(**options)
      assert_equal false, item.send(:reuse_allowed?)
      assert_raises(ArgumentError) { driver(**options, reuse_worker: true) }
    end
  end

  def test_auto_isolates_recorded_case_after_idle_persistent_worker
    item = driver
    item.visit("/")
    old_pid = item.worker.worker_pid
    item.reset!
    Dir.mktmpdir do |directory|
      Specdrive::ReportCase.capture(directory: directory, name: "recorded") do
        item.visit("/")
        refute_equal old_pid, item.worker.worker_pid
        refute item.diagnostics.fetch(:worker_reusable)
      end
      item.reset!
      refute item.diagnostics.fetch(:worker_started)
    end
    item.visit("/")
    assert item.diagnostics.fetch(:worker_reusable)
  end

  def test_forced_reuse_rejects_report_case
    item = driver(reuse_worker: true)
    Dir.mktmpdir do |directory|
      Specdrive::ReportCase.capture(directory: directory, name: "recorded") do
        assert_raises(ArgumentError) { item.visit("/") }
      end
    end
  end

  def test_unsafe_reset_fails_and_discards_worker
    item = driver
    item.visit("/")
    pid = item.worker.worker_pid
    item.command("confirm_arm", accept: true)
    error = assert_raises(Specdrive::Error) { item.reset! }
    assert_match(/UNSAFE_WORKER_RESET/, error.message)
    refute item.diagnostics.fetch(:worker_started)
    item.visit("/")
    refute_equal pid, item.worker.worker_pid
  end
end
