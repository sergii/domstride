require "minitest/autorun"
require "open3"
require "specdrive"
require "specdrive/capybara"

class SpecdriveCompatibilityTest < Minitest::Test
  def test_public_namespace_shares_existing_implementation
    assert_equal "Specdrive", Specdrive.name
    assert_equal "Specdrive::Session", Specdrive::Session.name
    assert_equal "Specdrive::Error", Specdrive::Error.name
    refute Object.const_defined?(:SpecDrive, false)
    assert_same Domstride, Specdrive
    assert_same Domstride::Session, Specdrive::Session
    assert_same Domstride::Configuration, Specdrive::Configuration
    assert_equal Domstride::VERSION, Specdrive::VERSION
    assert_equal "domstride.case", Specdrive::Protocol::FORMAT
  end

  def test_entrypoint_load_order_in_fresh_processes
    [%w[domstride specdrive], %w[specdrive domstride], %w[domstride/errors specdrive],
     %w[domstride/consumer specdrive], %w[specdrive/report domstride]].each do |requires|
      code = 'abort unless Specdrive.equal?(Domstride) && Specdrive.name == "Specdrive"; abort if Object.const_defined?(:SpecDrive, false)'
      output, status = Open3.capture2e(RbConfig.ruby, "-I", File.expand_path("../lib", __dir__), *requires.flat_map { |name| ["-r", name] }, "-e", code)
      assert status.success?, output
    end
  end

  def test_new_configuration_prefix_overrides_legacy_values
    env = {"DOMSTRIDE_ENGINE" => "jsdom", "SPECDRIVE_ENGINE" => "jsdom31",
           "DOMSTRIDE_PROFILE" => "1", "SPECDRIVE_PROFILE" => "0"}
    settings = Specdrive::Configuration.resolve(env: env)
    assert_equal "jsdom31", settings.fetch(:engine)
    assert_equal false, settings.fetch(:profile)
    assert_equal "jsdom", env.fetch("DOMSTRIDE_ENGINE")
    assert_equal "happy-dom", Specdrive::Configuration.resolve(env: {"SPECDRIVE_PERFORMANCE_PROFILE" => "fast"}).fetch(:engine)
    assert_equal "jsdom", Specdrive::Configuration.resolve(env: {"DOMSTRIDE_ENGINE" => "jsdom"}).fetch(:engine)
    assert_equal "jsdom31", Specdrive::Configuration.resolve(env: env, engine: "jsdom31").fetch(:engine)
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
