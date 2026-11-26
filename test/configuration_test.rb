require "minitest/autorun"
require "domstride"

class ConfigurationTest < Minitest::Test
  def test_legacy_defaults
    values = Domstride::Configuration.resolve(env: {})
    assert_equal "jsdom", values[:engine]
    assert_equal "real", values[:clock]
    assert_equal "off", values[:bundle_cache]
  end

  def test_profiles
    assert_equal "jsdom31", Domstride::Configuration.resolve(performance_profile: :compatible, env: {})[:engine]
    assert_equal "happy-dom", Domstride::Configuration.resolve(performance_profile: :fast, env: {})[:engine]
    settings = Domstride::Configuration.resolve(performance_profile: :deterministic, env: {})
    assert_equal ["jsdom31", "compiled", "observer", "tracked", "virtual"],
      settings.values_at(:engine, :bundle_cache, :wait_strategy, :settling, :clock)
  end

  def test_precedence
    settings = Domstride::Configuration.resolve(env: { "DOMSTRIDE_PERFORMANCE_PROFILE" => "fast", "DOMSTRIDE_ENGINE" => "jsdom31", "DOMSTRIDE_PROFILE" => "1" }, engine: "jsdom")
    assert_equal "jsdom", settings[:engine]
    assert settings[:profile]
    assert_raises(ArgumentError) { Domstride::Configuration.resolve(performance_profile: :missing, env: {}) }
    assert_raises(ArgumentError) { Domstride::Configuration.resolve(env: {}, typo: true) }
  end
end
