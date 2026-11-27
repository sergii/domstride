require "minitest/autorun"
require "domstride/bdd"

class BDDTest < Minitest::Test
  def app
    lambda do |env|
      signed = env.fetch("HTTP_COOKIE", "").include?("fixture=signed")
      headers = {"content-type" => "text/html"}
      headers["set-cookie"] = "fixture=signed; Path=/" if env["PATH_INFO"] == "/sign-in"
      [200, headers, ["<p id=identity>#{signed ? 'Signed in' : 'Anonymous'}</p>"]]
    end
  end

  def test_metadata_and_failure_propagation
    events = []
    scenario = Domstride::BDD::Scenario.new(app: app, driver: :domstride, on_event: ->(event) { events << event })
    assert_equal "value", scenario.step(kind: :custom) { "value" }
    error = assert_raises(RuntimeError) { scenario.step(kind: :assert) { raise "fixture failure" } }
    assert_equal "fixture failure", error.message
    assert_equal %w[step_started step_finished step_started step_finished], events.map { |e| e[:type] }
    assert_equal %w[passed failed], events.filter_map { |e| e[:status] }
    assert_equal [1, 1, 2, 2], events.map { |e| e[:sequence] }
    refute_includes events.to_s, "fixture failure"
    assert events.filter_map { |e| e[:duration_ms] }.all? { |ms| ms >= 0 }
    scenario.close
    scenario.close
    assert_raises(Domstride::Error) { scenario.step {} }
  ensure
    scenario&.close
  end

  def test_isolated_sessions_and_world_lifecycle
    world = Object.new.extend(Domstride::BDD::World)
    first = world.start_domstride_scenario(app: app, driver: :domstride)
    world.domstride_step(kind: :visit) { |page| page.visit("/sign-in") }
    first.page.visit("/")
    assert first.page.has_css?("#identity", exact_text: "Signed in")
    assert_raises(Domstride::Error) { world.start_domstride_scenario(app: app) }
    world.finish_domstride_scenario
    second = world.start_domstride_scenario(app: app, driver: :domstride)
    refute_same first.page, second.page
    second.page.visit("/")
    assert second.page.has_css?("#identity", exact_text: "Anonymous")
    world.finish_domstride_scenario
    assert_raises(Domstride::Error) { world.domstride_page }
  ensure
    world&.finish_domstride_scenario
  end
end
