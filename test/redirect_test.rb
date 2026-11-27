require "minitest/autorun"
require "domstride"

class RedirectTest < Minitest::Test
  def response(status, headers = {}, body = "")
    [status, { "content-type" => "text/html" }.merge(headers), [body]]
  end

  def test_visit_follows_relative_redirect_and_cookies
    app = lambda do |env|
      case env["PATH_INFO"]
      when "/start" then response(302, { "location" => "/nested/step", "set-cookie" => "session=abc; Path=/" })
      when "/nested/step" then response(301, { "location" => "done?from=step" })
      when "/nested/done" then response(200, {}, "<p id='result'>#{env["HTTP_COOKIE"]}:#{env["QUERY_STRING"]}</p>")
      else response(404)
      end
    end
    Domstride::Session.open(app: app) do |page|
      page.visit("/start")
      assert_equal "session=abc:from=step", page.text("#result")
      assert_equal "http://example.test/nested/done?from=step", page.dom_command("current_url")
    end
  end

  def test_rejects_external_redirect_and_loops
    app = lambda do |env|
      location = env["PATH_INFO"] == "/external" ? "https://outside.example/" : "/loop"
      response(302, { "location" => location })
    end
    Domstride::Session.open(app: app) do |page|
      assert_match(/same-origin/, assert_raises(Domstride::Error) { page.visit("/external") }.message)
      assert_match(/Redirect loop/, assert_raises(Domstride::Error) { page.visit("/loop") }.message)
    end
  end

  def test_redirect_limit
    app = ->(env) { response(302, { "location" => "/#{env["PATH_INFO"].delete_prefix("/").to_i + 1}" }) }
    Domstride::Session.open(app: app) do |page|
      assert_match(/Redirect limit/, assert_raises(Domstride::Error) { page.visit("/0") }.message)
    end
  end

  def test_fetch_redirect_method_semantics_and_final_url
    [301, 302, 303, 307, 308].each do |status|
      requests = []
      app = lambda do |env|
        case env["PATH_INFO"]
        when "/"
          response(200, {}, <<~HTML)
            <p id="result">Pending</p><button id="start">Start</button>
            <script>
              document.querySelector("#start").onclick = async () => {
                const response = await fetch("/submit", {method: "POST", body: new URLSearchParams({amount: "25"})});
                document.querySelector("#result").textContent = response.redirected + ":" + response.url + ":" + await response.text();
              };
            </script>
          HTML
        when "/submit"
          requests << [env["REQUEST_METHOD"], env["rack.input"]&.read.to_s]
          response(status, { "location" => "/done", "set-cookie" => "session=ok; Path=/" })
        when "/done"
          requests << [env["REQUEST_METHOD"], env["rack.input"]&.read.to_s]
          response(200, {}, env["HTTP_COOKIE"])
        else response(404)
        end
      end
      Domstride::Session.open(app: app) do |page|
        page.visit("/")
        page.click("#start")
        assert page.wait_for_text("#result", "true:http://example.test/done:session=ok")
        assert_equal ["POST", "amount=25"], requests.first
        assert_equal(status >= 307 ? ["POST", "amount=25"] : ["GET", ""], requests.last)
      end
    end
  end

  def test_fetch_error_and_manual_modes_fail_explicitly
    app = lambda do |env|
      if env["PATH_INFO"] == "/"
        response(200, {}, <<~HTML)
          <p id="result">Pending</p><button id="start">Start</button>
          <script>
            document.querySelector("#start").onclick = async () => {
              const errors = [];
              for (const redirect of ["error", "manual"]) {
                try { await fetch("/redirect", {redirect}); }
                catch (error) { errors.push(error.message); }
              }
              document.querySelector("#result").textContent = errors.join("|");
            };
          </script>
        HTML
      else
        response(302, { "location" => "/done" })
      end
    end
    Domstride::Session.open(app: app) do |page|
      page.visit("/")
      page.click("#start")
      assert page.wait_for_text("#result", "Redirect forbidden by fetch mode|UNSUPPORTED_MANUAL_REDIRECT")
    end
  end
end
