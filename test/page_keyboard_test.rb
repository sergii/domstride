require "minitest/autorun"
require "domstride/capybara"

class PageKeyboardTest < Minitest::Test
  def test_page_enter_submits_actual_form_with_focused_control
    skip "Logical DOM profile requires Node/jsdom" if ENV["DOMSTRIDE_RUNTIME"] == "bun" || ENV["DOMSTRIDE_ENGINE"] == "happy-dom"
    app = ->(_) { [200, {"content-type"=>"text/html"}, [<<~HTML]] }
      <form><input name="code" id="code"><button>Continue</button></form><output id="result">Pending</output>
      <script>
        document.querySelector("form").addEventListener("submit", event => {
          event.preventDefault();
          document.getElementById("result").textContent = new FormData(event.target).get("code");
        });
      </script>
    HTML
    driver = Domstride::CapybaraAdapter::Driver.new(app, dom_profile: "logical")
    driver.visit("/")
    driver.find_css("#code").first.set("123456")
    assert_equal "code", driver.evaluate_script("document.activeElement.id")
    driver.send_keys(:enter)
    assert_equal "123456", driver.find_css("#result").first.all_text
    driver.execute_script('document.querySelector("input").addEventListener("keydown", e => e.preventDefault()); document.getElementById("result").textContent = "Unchanged"')
    driver.send_keys(:enter)
    assert_equal "Unchanged", driver.find_css("#result").first.all_text
    assert_raises(Capybara::NotSupportedByDriverError) { driver.send_keys([:control, "a"]) }
  ensure
    driver&.quit
  end

  def test_scroll_intent_preserves_target_without_faking_coordinates
    skip "Logical DOM profile requires Node/jsdom" if ENV["DOMSTRIDE_RUNTIME"] == "bun" || ENV["DOMSTRIDE_ENGINE"] == "happy-dom"
    Domstride::Session.open(dom_profile: "logical") do |page|
      page.mount_html('<main><p id="target">Target</p></main>')
      page.execute_script('document.getElementById("target").scrollIntoView({block:"nearest",inline:"center"})')
      assert_equal({"target_path"=>[1,0,0],"block"=>"nearest","inline"=>"center","behavior"=>"auto"}, page.dom_command("logical_scroll_state"))
      assert_equal 0, page.evaluate_script("scrollY")
      assert_match(/UNSUPPORTED_SMOOTH_SCROLL/, assert_raises(Domstride::JavaScriptError) {
        page.execute_script('document.getElementById("target").scrollIntoView({behavior:"smooth"})')
      }.message)
      page.mount_html("<p>New</p>")
      assert_nil page.dom_command("logical_scroll_state")
    end
  end
end
