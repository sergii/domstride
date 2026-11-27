require "minitest/autorun"
require "domstride"

class ProfilerTest < Minitest::Test
  def test_profiles_successful_and_failed_commands_without_payloads
    Domstride::Session.open(profile: true) do |page|
      page.mount_html('<p id="status">Ready</p>')
      assert_equal "Ready", page.text("#status")
      assert_raises(Domstride::Error) { page.click("#absent") }
      profile = page.profile
      assert_equal 1, profile[:commands]["mount"][:count]
      assert_equal 1, profile[:commands]["click"][:count]
      assert_operator profile[:commands]["mount"][:worker_wall_ms], :>, 0
      assert_operator profile[:phases_ms]["worker.boot_engine"], :>, 0
      assert_operator profile[:phases_ms]["mount.create_window"], :>, 0
      assert_operator profile[:phases_ms]["mount.assets_total"], :>=, 0
      assert_operator profile[:bytes_sent], :>, 0
      assert_operator profile[:bytes_received], :>, 0
      refute_includes profile.inspect, "Ready"
      page.reset_profile!
      assert_empty page.profile[:commands]
      assert_empty page.profile[:phases_ms]
    end
  end

  def test_observer_detects_delayed_dom_mutation_and_times_out
    Domstride::Session.open(wait_strategy: "observer") do |page|
      page.mount_html('<p id="status">Pending</p><button id="start" onclick="setTimeout(() => document.querySelector(\'#status\').textContent = \'Done\', 25)">Start</button>')
      page.click("#start")
      assert page.wait_for_text("#status", "Done")
      assert_raises(Domstride::Error) { page.wait_for_text("#status", "Missing", timeout: 0.02) }
    end
  end

  def test_observer_surfaces_delayed_javascript_error
    Domstride::Session.open(wait_strategy: "observer") do |page|
      page.mount_html('<p id="status">Pending</p><button id="start" onclick="setTimeout(() => { throw new Error(\'observer failure\') }, 25)">Start</button>')
      error = assert_raises(Domstride::JavaScriptError) do
        page.click("#start")
        page.wait_for_text("#status", "Done")
      end
      assert_includes error.message, "observer failure"
    end
  end
end
