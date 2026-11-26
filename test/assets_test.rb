require "minitest/autorun"
require "domstride"

class AssetsTest < Minitest::Test
  def open_assets(app, &block)
    skip "Asset bundler requires Node and jsdom" if ENV["DOMSTRIDE_RUNTIME"] == "bun" || ENV["DOMSTRIDE_ENGINE"] == "happy-dom"
    Domstride::Session.open(app: app, assets: "bundle", bundle_cache: "off", &block)
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
