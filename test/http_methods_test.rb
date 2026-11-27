require "minitest/autorun"
require "domstride"

class HttpMethodsTest < Minitest::Test
  def test_fetch_accepts_document_abort_signal_without_replacing_dom_constructors
    requests = []
    app = lambda do |env|
      path = env["PATH_INFO"]
      if path == "/"
        [200, {"content-type" => "text/html"}, [<<~HTML]]
          <p id="result">Pending</p>
          <script>
            (async () => {
              const controller = new AbortController();
              let events = 0;
              document.addEventListener("probe", () => events++, {signal: controller.signal});
              document.dispatchEvent(new Event("probe"));
              const response = await fetch("/normal", {signal: controller.signal});
              controller.abort();
              document.dispatchEvent(new Event("probe"));
              let aborted;
              try { await fetch("/must-not-dispatch", {signal: controller.signal}); }
              catch (error) { aborted = error.name; }
              const active = new AbortController();
              const inFlight = fetch("/already-dispatched", {signal: active.signal});
              active.abort();
              let inFlightAbort;
              try { await inFlight; } catch (error) { inFlightAbort = error.name; }
              document.querySelector("#result").textContent =
                (await response.text()) + ":" + events + ":" + aborted + ":" + inFlightAbort;
            })();
          </script>
        HTML
      else
        requests << path
        [200, {"content-type" => "text/plain"}, ["OK"]]
      end
    end
    Domstride::Session.open(app: app) do |page|
      page.visit("/")
      assert page.wait_for_text("#result", "OK:1:AbortError:AbortError")
      assert_equal ["/normal", "/already-dispatched"], requests
    end
  end

  def test_mutating_methods_and_head
    requests = []
    app = lambda do |env|
      if env["PATH_INFO"] == "/"
        [200, {"content-type" => "text/html"}, [<<~HTML]]
          <p id="result">Pending</p><button id="start">Start</button>
          <script>
            document.querySelector("#start").onclick = async () => {
              for (const method of ["PATCH", "PUT", "DELETE"]) {
                const response = await fetch("/record", {method, headers: {"Content-Type":"application/json"}, body: JSON.stringify({amount:25})});
                if (response.status !== 204) throw new Error("Unexpected status");
              }
              const head = await fetch("/record", {method:"HEAD"});
              document.querySelector("#result").textContent = head.status + ":" + await head.text();
            };
          </script>
        HTML
      else
        requests << [env["REQUEST_METHOD"], env["rack.input"]&.read.to_s, env["HTTP_ORIGIN"]]
        [env["REQUEST_METHOD"] == "HEAD" ? 200 : 204, {}, []]
      end
    end
    Domstride::Session.open(app: app) do |page|
      page.visit("/")
      page.click("#start")
      assert page.wait_for_text("#result", "200:")
      assert_equal %w[PATCH PUT DELETE HEAD], requests.map(&:first)
      assert_equal ['{"amount":25}'] * 3, requests.first(3).map { |row| row[1] }
      assert_equal ["http://example.test"] * 3, requests.first(3).map { |row| row[2] }
    end
  end
end
