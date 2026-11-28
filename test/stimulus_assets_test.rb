require "minitest/autorun"
require "domstride"

class StimulusAssetsTest < Minitest::Test
  def test_real_stimulus_with_computed_controller_imports
    skip "Asset bundler requires Node" if ENV["DOMSTRIDE_RUNTIME"] == "bun" || ENV["DOMSTRIDE_ENGINE"] == "happy-dom"
    exercise_stimulus
  end

  def test_happy_dom_real_stimulus_with_computed_controller_imports
    skip "Experimental asset bridge requires Node" if ENV["DOMSTRIDE_RUNTIME"] == "bun"
    exercise_stimulus(engine: "happy-dom", runtime: "node")
  end

  private

  def exercise_stimulus(**options)
    root = File.expand_path("..", __dir__)
    stimulus = File.read(File.join(root, "node_modules/@hotwired/stimulus/dist/stimulus.js"))
    app = lambda do |env|
      path = env["PATH_INFO"]
      case path
      when "/"
        [200, {"content-type" => "text/html"}, [<<~HTML]]
          <!doctype html><html><head>
            <script type="importmap">{"imports":{"application":"/assets/application.js","@hotwired/stimulus":"/assets/stimulus.js","controllers/counter_controller":"/assets/counter.js"}}</script>
            <script type="module">import "application";</script>
          </head><body>
            <section data-controller="counter">
              <button id="increment" data-action="counter#increment">Add</button>
              <output id="count" data-counter-target="count">0</output>
            </section>
          </body></html>
        HTML
      when "/assets/stimulus.js"
        [200, {"content-type" => "text/javascript"}, [stimulus]]
      when "/assets/application.js"
        [200, {"content-type" => "text/javascript"}, [<<~JS]]
          import { Application } from "@hotwired/stimulus";
          const app = Application.start();
          const pins = JSON.parse(document.querySelector('script[type="importmap"]').textContent).imports;
          Object.keys(pins).filter(name => name.startsWith("controllers/")).forEach(async name => {
            const module = await import(name);
            app.register("counter", module.default);
          });
        JS
      when "/assets/counter.js"
        [200, {"content-type" => "text/javascript"}, [<<~JS]]
          import { Controller } from "@hotwired/stimulus";
          export default class extends Controller {
            static targets = ["count"];
            connect() { this.element.dataset.ready = "true"; }
            increment() { this.countTarget.textContent = Number(this.countTarget.textContent) + 1; }
          }
        JS
      else [404, {}, []]
      end
    end
    Domstride::Session.open(app: app, assets: "bundle", bundle_cache: "off", **options) do |page|
      page.visit("/")
      assert page.wait_for_text('[data-ready="true"] #count', "0")
      page.click("#increment")
      assert page.wait_for_text("#count", "1")
    end
  end
end
