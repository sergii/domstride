require "minitest/autorun"
require "domstride/capybara"

class PersistentWorkerTest < Minitest::Test
  def test_reset_reuses_pid_but_not_document_or_cookie_state
    previous = ENV["DOMSTRIDE_REUSE_WORKER"]
    ENV["DOMSTRIDE_REUSE_WORKER"] = "1"
    requests = []
    app = lambda do |env|
      requests << env["PATH_INFO"]
      if env["PATH_INFO"] == "/set"
        [200, {"content-type" => "text/html", "set-cookie" => "token=first; Path=/"}, [<<~HTML]]
          <p id="result">first</p>
          <script>
            window.probe = "old";
            localStorage.setItem("probe", "old");
            sessionStorage.setItem("probe", "old");
            setTimeout(() => fetch("/late"), 500);
          </script>
        HTML
      else
        cookie = env["HTTP_COOKIE"].to_s.include?("token=first") ? "leaked" : "clean"
        [200, {"content-type" => "text/html"}, ["<p id='result'>#{cookie}</p>"]]
      end
    end
    driver = Domstride::CapybaraAdapter::Driver.new(app, engine: "jsdom31", runtime: "node",
      clock: "real", assets: "off", websocket_url: nil, bundle_cache: "off")
    driver.visit("/set")
    pid = driver.worker.worker_pid
    old = driver.find_css("#result").first
    mounted = driver.worker.dom_command("memory_state")
    assert_equal pid, mounted.fetch("pid")
    assert_equal true, mounted.fetch("has_document")
    assert_operator mounted.fetch("handles"), :>, 0
    assert_operator mounted.fetch("heapUsed"), :>, 0
    driver.reset!
    reset = driver.worker.dom_command("memory_state")
    assert_equal pid, reset.fetch("pid")
    assert_equal false, reset.fetch("has_document")
    assert_equal 0, reset.fetch("handles")
    assert_equal 0, reset.fetch("pending_requests")
    assert_equal 0, reset.fetch("active_fetches")
    assert_equal "about:blank", driver.current_url
    assert_equal "", driver.html
    assert_raises(Domstride::CapybaraAdapter::StaleElement) { old.all_text }
    driver.visit("/")
    assert_equal pid, driver.worker.worker_pid
    assert_equal "clean", driver.find_css("#result").first.all_text
    assert_equal true, driver.evaluate_script("typeof window.probe === 'undefined' && localStorage.getItem('probe') === null && sessionStorage.getItem('probe') === null")
    sleep 0.55
    assert_equal "clean", driver.find_css("#result").first.all_text
    refute_includes requests, "/late"
    driver.quit
    refute driver.diagnostics[:worker_started]
  ensure
    driver&.quit
    ENV["DOMSTRIDE_REUSE_WORKER"] = previous
  end
end
