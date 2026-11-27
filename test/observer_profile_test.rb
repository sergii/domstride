require "minitest/autorun"
require "domstride"

class ObserverProfileTest < Minitest::Test
  def with_page(profile, &block)
    skip "Observer profiles require Node/jsdom" if ENV["DOMSTRIDE_RUNTIME"] == "bun" || ENV["DOMSTRIDE_ENGINE"] == "happy-dom"
    Domstride::Session.open(observer_profile: profile, &block)
  end

  def test_manual_intersection_is_explicit_and_tracks_transitions
    with_page("manual") do |page|
      page.mount_html(<<~HTML)
        <p id="target">Target</p><output id="result">Pending</output>
        <script>
          window.intersection = new IntersectionObserver(entries => {
            const e = entries[0];
            document.getElementById("result").textContent = e.isIntersecting + ":" + e.intersectionRatio;
          });
          intersection.observe(document.getElementById("target"));
        </script>
      HTML
      assert_equal "Pending", page.text("#result")
      assert_equal 1, page.notify_intersection("#target", intersecting: true)
      assert_equal "true:1", page.text("#result")
      assert_equal 0, page.notify_intersection("#target", intersecting: true)
      assert_equal 1, page.notify_intersection("#target", intersecting: false)
      assert_equal "false:0", page.text("#result")
      page.execute_script("intersection.disconnect()")
      assert_equal 0, page.notify_intersection("#target", intersecting: true)
    end
  end

  def test_logical_visibility_excludes_hidden_and_closed_dialog_targets
    with_page("logical-visible") do |page|
      page.mount_html(<<~HTML)
        <p id="visible">Shown</p><dialog><p id="closed">Closed</p></dialog>
        <p id="hidden" hidden>Hidden</p><output id="result"></output>
        <script>
          const observer = new IntersectionObserver(entries => {
            for (const e of entries) document.getElementById("result").textContent += e.target.id + ":" + e.isIntersecting + ";";
          });
          for (const id of ["visible","closed","hidden"]) observer.observe(document.getElementById(id));
        </script>
      HTML
      assert page.wait_for_text("#result", "visible:true;closed:false;hidden:false;")
      assert_equal "undefined", page.evaluate_script("typeof ResizeObserver")
    end
  end

  def test_resize_uses_only_explicit_dimensions_and_unobserve
    with_page("manual") do |page|
      page.mount_html(<<~HTML)
        <p id="target">Target</p><output id="result">Pending</output>
        <script>
          window.resize = new ResizeObserver(entries => {
            const e = entries[0];
            document.getElementById("result").textContent = e.contentRect.width + "x" + e.contentBoxSize[0].blockSize;
          });
          resize.observe(document.getElementById("target"));
        </script>
      HTML
      assert_equal "Pending", page.text("#result")
      assert_equal 1, page.notify_resize("#target", width: 320, height: 80)
      assert_equal "320x80", page.text("#result")
      assert_equal 0, page.notify_resize("#target", width: 320, height: 80)
      assert_equal 1, page.notify_resize("#target", width: 640, height: 100)
      assert_equal "640x100", page.text("#result")
      page.execute_script('resize.unobserve(document.getElementById("target"))')
      assert_equal 0, page.notify_resize("#target", width: 700, height: 100)
    end
  end
end
