require "minitest/autorun"
require "domstride"

class HappyDomAssetsTest < Minitest::Test
  def open_assets(app, **options, &block)
    skip "Experimental asset bridge requires Node" if ENV["DOMSTRIDE_RUNTIME"] == "bun"
    Domstride::Session.open(app: app, engine: "happy-dom", runtime: "node",
      assets: "bundle", bundle_cache: "off", **options, &block)
  end

  def test_importmap_and_classic_scripts_execute_once_in_selected_dom
    requests = []
    source = "export const value = 'first';"
    html = <<~HTML
      <!doctype html><html><head>
        <script src="/classic.js"></script>
        <script type="importmap">{"imports":{"app":"/app.js"}}</script>
        <script type="module">import "app";</script>
      </head><body><p id="result">Pending</p></body></html>
    HTML
    app = lambda do |env|
      path = env.fetch("PATH_INFO")
      requests << path
      case path
      when "/" then [200, {"content-type" => "text/html"}, [html]]
      when "/classic.js" then [200, {"content-type" => "text/javascript"}, ['window.executions = (window.executions || 0) + 1;']]
      when "/app.js" then [200, {"content-type" => "text/javascript"}, ['import {value} from "./dep.js"; document.querySelector("#result").textContent = String(window.executions) + ":" + value;']]
      when "/dep.js" then [200, {"content-type" => "text/javascript"}, [source]]
      else [404, {}, []]
      end
    end
    previous = ENV["DOMSTRIDE_IMPORTMAP_CACHE"]
    ENV["DOMSTRIDE_IMPORTMAP_CACHE"] = "1"
    open_assets(app, profile: true) do |page|
      pid = page.worker_pid
      assert_equal "happy-dom", page.settings.fetch(:engine)
      page.visit("/")
      assert page.wait_for_text("#result", "1:first")
      assert_equal 1, page.profile[:importmap_misses]
      page.reset_document!
      page.visit("/")
      assert page.wait_for_text("#result", "1:first")
      assert_equal 1, page.profile[:importmap_hits]
      page.reset_document!
      source = "export const value = 'changed';"
      page.visit("/")
      assert page.wait_for_text("#result", "1:changed")
      assert_equal 2, page.profile[:importmap_misses]
      assert_equal 3, requests.count("/dep.js")
      assert_equal pid, page.worker_pid
    end
  ensure
    ENV["DOMSTRIDE_IMPORTMAP_CACHE"] = previous
  end

  def test_module_error_propagates
    app = ->(_) { [200, {"content-type" => "text/html"}, ['<script type="module">throw new Error("happy-assets-sentinel");</script>']] }
    open_assets(app) do |page|
      assert_match(/happy-assets-sentinel/, assert_raises(Domstride::JavaScriptError) { page.visit("/") }.message)
    end
  end

  def test_remote_assets_are_rejected
    app = ->(_) { [200, {"content-type" => "text/html"}, ['<script src="https://outside.example/app.js"></script>']] }
    open_assets(app) do |page|
      assert_match(/UNSUPPORTED_EXTERNAL_ASSET/, assert_raises(Domstride::Error) { page.visit("/") }.message)
    end
  end
end
