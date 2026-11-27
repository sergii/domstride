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

  def test_asset_preparse_is_inert_with_either_jsdom_engine
    app = ->(_) { [200, {"content-type" => "text/html"}, [<<~HTML]] }
      <p id="result">Pending</p>
      <script>window.executions = (window.executions || 0) + 1;</script>
      <script type="module">
        document.querySelector("#result").textContent = String(window.executions);
      </script>
    HTML
    %w[jsdom jsdom31].each do |engine|
      open_assets(app, engine: engine, profile: true) do |page|
        page.visit("/")
        assert_equal "1", page.text("#result")
        assert_operator page.profile[:phases_ms]["assets.parse_html"], :>, 0
      end
    end
  end

  def test_opt_in_importmap_cache_revalidates_transitive_content_and_keeps_html_fresh
    previous = ENV["DOMSTRIDE_IMPORTMAP_CACHE"]
    ENV["DOMSTRIDE_IMPORTMAP_CACHE"] = "1"
    source = "export const value = 'first';"
    label = "page one"
    requests = []
    app = lambda do |env|
      path = env["PATH_INFO"]
      requests << path
      case path
      when "/"
        [200, {"content-type" => "text/html"}, ["<p id='label'>#{label}</p><p id='result'></p><script type='importmap'>{\"imports\":{\"app\":\"/app.js\"}}</script><script type='module'>import 'app';</script>"]]
      when "/app.js"
        [200, {"content-type" => "text/javascript"}, ["import {value} from './dep.js'; document.querySelector('#result').textContent = value;"]]
      when "/dep.js"
        [200, {"content-type" => "text/javascript"}, [source]]
      else
        [404, {}, []]
      end
    end
    open_assets(app, engine: "jsdom31", profile: true, asset_warnings: "strict") do |page|
      page.visit("/")
      assert_equal "first", page.text("#result")
      assert_equal 1, page.profile[:importmap_misses]
      page.reset_document!
      label = "page two"
      page.visit("/")
      assert_equal "page two", page.text("#label")
      assert_equal "first", page.text("#result")
      assert_equal 1, page.profile[:importmap_hits]
      page.reset_document!
      source = "export const value = 'changed';"
      page.visit("/")
      assert_equal "changed", page.text("#result")
      assert_equal 2, page.profile[:importmap_misses]
      assert_equal 3, requests.count("/dep.js")
    end
  ensure
    ENV["DOMSTRIDE_IMPORTMAP_CACHE"] = previous
  end

  def test_binary_tagged_utf8_html_and_javascript_preserve_unicode
    app = lambda do |env|
      case env["PATH_INFO"]
      when "/"
        html = '<p id="result">Очікування</p><script src="/classic.js"></script><script type="importmap">{"imports":{"application":"/app.js"}}</script><script type="module">import "application";</script>'
        [200, {"content-type" => "text/html; charset=utf-8"}, [html.b]]
      when "/classic.js"
        [200, {"content-type" => "text/javascript"}, ['window.prefix = "© ";'.b]]
      when "/app.js"
        [200, {"content-type" => "application/javascript"}, ['document.querySelector("#result").textContent = window.prefix + "€ Україна 🐾";'.b]]
      else
        [404, {}, []]
      end
    end
    open_assets(app) do |page|
      page.visit("/")
      assert page.wait_for_text("#result", "© € Україна 🐾")
    end
  end

  def test_invalid_utf8_asset_fails_explicitly
    app = lambda do |env|
      if env["PATH_INFO"] == "/"
        [200, {"content-type" => "text/html"}, ['<script type="module" src="/app.js"></script>']]
      else
        [200, {"content-type" => "application/javascript"}, ["\xFF".b]]
      end
    end
    open_assets(app) do |page|
      error = assert_raises(Domstride::Error) { page.visit("/") }
      assert_match(/Rack response body is not valid UTF-8/, error.message)
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
