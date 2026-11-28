require "minitest/autorun"
require "open3"
require "specdrive"
require "specdrive/capybara"

class SpecDriveCompatibilityTest < Minitest::Test
  def test_public_namespace_shares_existing_implementation
    assert_same Domstride, SpecDrive
    assert_same Domstride::Session, SpecDrive::Session
    assert_same Domstride::Configuration, SpecDrive::Configuration
    assert_equal Domstride::VERSION, SpecDrive::VERSION
    assert_equal "domstride.case", SpecDrive::Protocol::FORMAT
  end

  def test_new_configuration_prefix_overrides_legacy_values
    env = {"DOMSTRIDE_ENGINE" => "jsdom", "SPECDRIVE_ENGINE" => "jsdom31",
           "DOMSTRIDE_PROFILE" => "1", "SPECDRIVE_PROFILE" => "0"}
    settings = SpecDrive::Configuration.resolve(env: env)
    assert_equal "jsdom31", settings.fetch(:engine)
    assert_equal false, settings.fetch(:profile)
    assert_equal "jsdom", env.fetch("DOMSTRIDE_ENGINE")
    assert_equal "happy-dom", SpecDrive::Configuration.resolve(env: {"SPECDRIVE_PERFORMANCE_PROFILE" => "fast"}).fetch(:engine)
    assert_equal "jsdom", SpecDrive::Configuration.resolve(env: {"DOMSTRIDE_ENGINE" => "jsdom"}).fetch(:engine)
    assert_equal "jsdom31", SpecDrive::Configuration.resolve(env: env, engine: "jsdom31").fetch(:engine)
  end

  def test_both_driver_names_remain_available
    assert Capybara.drivers.key?(:domstride)
    assert Capybara.drivers.key?(:specdrive)
    app = ->(_) { [200, {"content-type" => "text/html"}, ["<p id='status'>Ready</p>"]] }
    [:domstride, :specdrive].each do |name|
      page = Capybara::Session.new(name, app)
      begin
        page.visit("/")
        assert page.has_css?("#status", text: "Ready")
      ensure
        page.driver.quit
      end
    end
  end
end
