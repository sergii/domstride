require "minitest/autorun"
require "domstride"

class AssetsTest < Minitest::Test
  def open_assets(app, **options, &block)
    skip "Asset bundler requires Node and jsdom" if ENV["DOMSTRIDE_RUNTIME"] == "bun" || ENV["DOMSTRIDE_ENGINE"] == "happy-dom"
    Domstride::Session.open(app: app, assets: "bundle", bundle_cache: "off", **options, &block)
  end

  def test_classic_and_importmap_assets_run_through_rack
    requests = []
    app = lambda do |env|
      path = env["PATH_INFO"]
      requests << path
      case path
      when "/"
        [200, {"content-type" => "text/html"}, [<<~HTML]]
          <!doctype html><html><head>
            <script src="/assets/classic.js"></script>
            <script type="importmap">{"imports":{"application":"/assets/app.js","lib/":"/assets/lib/"}}</script>
            <script type="module">import "application";</script>
          </head><body><p id="result">Pending</p></body></html>
        HTML
      when "/assets/classic.js"
        [200, {"content-type" => "text/javascript"}, ['window.classicValue = "classic";']]
      when "/assets/app.js"
        [200, {"content-type" => "application/javascript"}, ['import {value} from "lib/value.js"; import {suffix} from "./suffix.js"; document.querySelector("#result").textContent = window.classicValue + value + suffix;']]
      when "/assets/lib/value.js"
        [200, {"content-type" => "text/javascript"}, ['export const value = "-module";']]
      when "/assets/suffix.js"
        [200, {"content-type" => "text/javascript"}, ['export const suffix = "-relative";']]
      else
        [404, {}, []]
      end
    end
    open_assets(app) do |page|
      page.visit("/")
      assert page.wait_for_text("#result", "classic-module-relative")
      assert_equal ["/", "/assets/app.js", "/assets/classic.js", "/assets/lib/value.js", "/assets/suffix.js"].sort, requests.sort
    end
  end

  def test_direct_eval_warning_policy_is_explicit
    app = ->(_) { [200, {"content-type" => "text/html"}, ['<p id="result">Pending</p><script type="module">export function total() { const amount = 25; return eval("amount + 1"); } document.getElementById("result").textContent = String(total());</script>']] }
    open_assets(app, asset_warnings: "strict") do |page|
      assert_match(/direct-eval/, assert_raises(Domstride::Error) { page.visit("/") }.message)
    end
    open_assets(app, asset_warnings: "direct-eval") do |page|
      page.visit("/")
      assert_equal "26", page.text("#result")
    end
  end

  def test_direct_eval_policy_does_not_hide_runtime_or_resolution_errors
    bad = ->(_) { [200, {"content-type" => "text/html"}, ['<script type="module">eval("throw new Error(String(12345))");</script>']] }
    open_assets(bad, asset_warnings: "direct-eval") do |page|
      assert_match(/12345/, assert_raises(Domstride::JavaScriptError) { page.visit("/") }.message)
    end
    unresolved = ->(_) { [200, {"content-type" => "text/html"}, ['<script type="module">import "missing";</script>']] }
    open_assets(unresolved, asset_warnings: "direct-eval") do |page|
      assert_match(/UNRESOLVED_IMPORT/, assert_raises(Domstride::Error) { page.visit("/") }.message)
    end
  end

  def test_external_and_unresolved_assets_fail_explicitly
    [
      ['<script src="https://outside.example/app.js"></script>', /UNSUPPORTED_EXTERNAL_ASSET/],
      ['<script type="module">import "missing"</script>', /UNRESOLVED_IMPORT/]
    ].each do |html, pattern|
      app = ->(_) { [200, {"content-type" => "text/html"}, [html]] }
      open_assets(app) do |page|
        assert_match pattern, assert_raises(Domstride::Error) { page.visit("/") }.message
      end
    end
  end
end
