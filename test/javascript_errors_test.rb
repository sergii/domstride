require "minitest/autorun"
require "domstride"

class JavaScriptErrorsTest < Minitest::Test
  def test_inline_script_error_is_not_silently_ignored
    Domstride::Session.open do |page|
      error = assert_raises(Domstride::JavaScriptError) do
        page.mount_html('<script>throw new Error("boot failure")</script>')
      end
      assert_includes error.message, "boot failure"
    end
  end

  def test_event_handler_error_is_raised_by_click
    Domstride::Session.open do |page|
      page.mount_html('<button id="bad">Bad</button><script>document.querySelector("#bad").addEventListener("click", () => { throw new Error("click failure") })</script>')
      error = assert_raises(Domstride::JavaScriptError) { page.click("#bad") }
      assert_includes error.message, "click failure"
    end
  end

  def test_rejected_promise_is_reported
    Domstride::Session.open do |page|
      page.mount_html('<button id="bad">Bad</button><script>document.querySelector("#bad").addEventListener("click", () => Promise.reject(new Error("rejected promise")))</script>')
      error = assert_raises(Domstride::JavaScriptError) { page.click("#bad"); page.check_javascript! }
      assert_includes error.message, "rejected promise"
    end
  end

  def test_delayed_error_interrupts_wait
    Domstride::Session.open do |page|
      page.mount_html('<output id="status">Pending</output><button id="bad">Bad</button><script>document.querySelector("#bad").addEventListener("click", () => setTimeout(() => { throw new Error("timer failure") }, 25))</script>')
      error = assert_raises(Domstride::JavaScriptError) { page.click("#bad"); page.wait_for_text("#status", "Done") }
      assert_includes error.message, "timer failure"
    end
  end

  def test_batch_stops_on_javascript_error
    Domstride::Session.open do |page|
      page.mount_html('<output id="status">Pending</output><button id="bad" onclick="throw new Error(\'batch failure\')">Bad</button><button id="good" onclick="document.querySelector(\'#status\').textContent=\'Done\'">Good</button>')
      error = assert_raises(Domstride::JavaScriptError) do
        page.batch { |b| b.click("#bad"); b.click("#good") }
      end
      assert_includes error.message, "batch failure"
      assert_equal "Pending", page.text("#status")
    end
  end

  def test_plain_console_error_is_diagnostic
    Domstride::Session.open do |page|
      page.mount_html('<script>console.error("diagnostic message")</script><p id="ok">OK</p>')
      assert page.check_javascript!
      assert_equal "OK", page.text("#ok")
    end
  end
end
