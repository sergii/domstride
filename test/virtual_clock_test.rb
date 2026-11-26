require "minitest/autorun"
require "domstride"

class VirtualClockTest < Minitest::Test
  def open_clock(&block)
    Domstride::Session.open(clock: "virtual", settling: "tracked", &block)
  end

  def test_timer_order_cancellation_and_date
    open_clock do |page|
      page.mount_html(<<~HTML)
        <p id="log"></p><script>
          const append = s => document.querySelector("#log").textContent += s;
          const start = Date.now();
          const cancelled = setTimeout(() => append("bad"), 50);
          clearTimeout(cancelled);
          setTimeout(() => { append("A"); Promise.resolve().then(() => append("P")); }, 100);
          setTimeout(() => append("B" + (Date.now() - start)), 100);
        </script>
      HTML
      assert_equal "", page.text("#log")
      page.advance_time(99)
      assert_equal "", page.text("#log")
      page.advance_time(1)
      assert_equal "APB100", page.text("#log")
      assert_equal 100, page.clock_state.fetch("now_ms")
    end
  end

  def test_interval_and_animation_frame
    open_clock do |page|
      page.mount_html(<<~HTML)
        <p id="log"></p><script>
          let ticks = 0;
          const id = setInterval(() => {
            document.querySelector("#log").textContent += "I";
            if (++ticks === 3) clearInterval(id);
          }, 10);
          requestAnimationFrame(t => document.querySelector("#log").textContent += "F" + t);
        </script>
      HTML
      page.advance_time(100)
      assert_equal "IF16II", page.text("#log")
      assert_equal 0, page.clock_state.fetch("pending_timers")
    end
  end

  def test_wait_advances_virtual_time_and_remount_resets_it
    open_clock do |page|
      page.mount_html('<p id="status">Pending</p><script>setTimeout(() => document.querySelector("#status").textContent = "Done", 5000)</script>')
      assert page.wait_for_text("#status", "Done", timeout: 6)
      assert_equal 5000, page.clock_state.fetch("now_ms")
      page.mount_html('<p id="status">New</p>')
      assert_equal 0, page.clock_state.fetch("now_ms")
      assert_equal 0, page.clock_state.fetch("pending_timers")
    end
  end

  def test_virtual_timer_errors_propagate
    open_clock do |page|
      page.mount_html('<script>setTimeout(() => { throw new Error("virtual failure") }, 50)</script>')
      error = assert_raises(Domstride::JavaScriptError) { page.advance_time(50) }
      assert_includes error.message, "virtual failure"
    end
  end

  def test_callback_budget_bounds_repeating_timers
    open_clock do |page|
      page.mount_html('<script>setInterval(() => {}, 1)</script>')
      error = assert_raises(Domstride::Error) { page.advance_time(2000) }
      assert_includes error.message, "callback limit"
    end
  end

  def test_settling_tracks_nested_rack_fetches
    app = lambda do |env|
      if env["PATH_INFO"] == "/"
        [200, { "content-type" => "text/html" }, ['<p id="status">Pending</p><button id="start">Start</button><script>document.querySelector("#start").onclick = async () => { const a = await (await fetch("/first")).text(); const b = await (await fetch("/second")).text(); document.querySelector("#status").textContent = a + b; };</script>']]
      else
        [200, { "content-type" => "text/plain" }, [env["PATH_INFO"] == "/first" ? "A" : "B"]]
      end
    end
    Domstride::Session.open(app: app, settling: "tracked") do |page|
      page.visit("/")
      page.click("#start")
      assert_equal "AB", page.text("#status")
    end
  end
end
