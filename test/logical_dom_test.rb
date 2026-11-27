require "minitest/autorun"
require "domstride"

class LogicalDOMTest < Minitest::Test
  def with_page(&block)
    skip "Logical DOM profile requires Node/jsdom" if ENV["DOMSTRIDE_RUNTIME"] == "bun" || ENV["DOMSTRIDE_ENGINE"] == "happy-dom"
    Domstride::Session.open(dom_profile: "logical", &block)
  end

  def test_visibility_distinguishes_box_and_optional_css_properties
    with_page do |page|
      page.mount_html(<<~HTML)
        <div id="shown">Visible</div>
        <div style="display:none"><span id="nested">Hidden</span></div>
        <div id="contents" style="display:contents"><span>Child</span></div>
        <div id="opacity" style="opacity:0">Transparent</div>
        <div id="visibility" style="visibility:hidden">Invisible</div>
      HTML
      assert_equal [true, false, false, true, false, true, false, false], page.evaluate_script(<<~JS)
        [
          document.getElementById("shown").checkVisibility(),
          document.getElementById("nested").checkVisibility(),
          document.getElementById("contents").checkVisibility(),
          document.getElementById("opacity").checkVisibility(),
          document.getElementById("opacity").checkVisibility({opacityProperty:true}),
          document.getElementById("visibility").checkVisibility(),
          document.getElementById("visibility").checkVisibility({visibilityProperty:true}),
          document.createElement("div").checkVisibility()
        ]
      JS
      assert_match(/UNSUPPORTED_CONTENT_VISIBILITY_AUTO/, assert_raises(Domstride::JavaScriptError) {
        page.evaluate_script('document.body.checkVisibility({contentVisibilityAuto:true})')
      }.message)
    end
  end

  def test_dialog_lifecycle_and_close_event
    with_page do |page|
      page.mount_html('<dialog id="dialog">Example</dialog><p id="events">0</p>')
      page.execute_script(<<~JS)
        const dialog = document.getElementById("dialog");
        dialog.addEventListener("close", () => document.getElementById("events").textContent = "1");
        dialog.showModal();
      JS
      assert_equal true, page.evaluate_script('document.getElementById("dialog").open')
      assert_match(/already open/, assert_raises(Domstride::JavaScriptError) {
        page.execute_script('document.getElementById("dialog").show()')
      }.message)
      page.execute_script('document.getElementById("dialog").close("saved")')
      assert_equal false, page.evaluate_script('document.getElementById("dialog").open')
      assert_equal "saved", page.evaluate_script('document.getElementById("dialog").returnValue')
      assert page.wait_for_text("#events", "1")
      page.execute_script('document.getElementById("dialog").close("ignored")')
      assert_equal "saved", page.evaluate_script('document.getElementById("dialog").returnValue')
    end
  end

  def test_scroll_offsets_and_events_without_layout
    with_page do |page|
      page.mount_html('<p id="scroll">Pending</p>')
      page.execute_script(<<~JS)
        window.addEventListener("scroll", () => document.getElementById("scroll").textContent = String(scrollY));
        scrollTo(10, 120);
        scrollBy({top:30,left:-20});
      JS
      assert_equal [0,150,0,150], page.evaluate_script('[scrollX,scrollY,pageXOffset,pageYOffset]')
      assert page.wait_for_text("#scroll", "150")
      page.execute_script('scrollTo({top:0,behavior:"instant"})')
      assert_equal 0, page.evaluate_script('scrollY')
      assert_match(/UNSUPPORTED_SMOOTH_SCROLL/, assert_raises(Domstride::JavaScriptError) {
        page.execute_script('scrollTo({top:100,behavior:"smooth"})')
      }.message)
      page.mount_html("<p>New page</p>")
      assert_equal 0, page.evaluate_script('scrollY')
    end
  end

  def test_invalid_profile
    assert_raises(ArgumentError) { Domstride::Session.new(dom_profile: "unknown") }
  end
end
