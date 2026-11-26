require "minitest/autorun"
require "domstride/rails"
require "generators/domstride/install_generator"
require "tmpdir"

class DeveloperExperienceTest < Minitest::Test
  def test_explicit_driver_selection
    assert_equal :domstride, Domstride::RailsSupport.driver_name(env: {})
    assert_equal :selenium_chrome_headless, Domstride::RailsSupport.driver_name(env: {"DOMSTRIDE_DRIVER" => "browser"})
    assert_raises(ArgumentError) { Domstride::RailsSupport.driver_name(env: {"DOMSTRIDE_DRIVER" => "auto"}) }
    assert_raises(ArgumentError) { Domstride::RailsSupport.driver_name(env: {"DOMSTRIDE_DRIVER" => "browser", "DOMSTRIDE_BROWSER_DRIVER" => "missing-driver"}) }
  end

  def test_generator_preserves_existing_application_base
    Dir.mktmpdir do |directory|
      FileUtils.mkdir_p(File.join(directory, "test"))
      original = File.join(directory, "test/application_system_test_case.rb")
      File.write(original, "# Existing configuration\n")
      generator = Domstride::Generators::InstallGenerator.new([], {}, {destination_root: directory})
      generator.invoke_all
      generated = File.join(directory, "test/domstride_system_test_case.rb")
      assert File.file?(generated)
      assert_includes File.read(generated), "driven_by Domstride::RailsSupport.driver_name"
      assert_equal "# Existing configuration\n", File.read(original)
      generator.invoke_all
      assert_equal "# Existing configuration\n", File.read(original)
    end
  end

  def test_failure_diagnostics_do_not_save_html_by_default
    driver = Domstride::CapybaraAdapter::Driver.new(->(_) { [200, {}, []] })
    Dir.mktmpdir do |directory|
      path = Domstride::RailsSupport.save_failure(driver, directory: directory)
      report = JSON.parse(File.read(File.join(path, "diagnostics.json")))
      assert_equal false, report.fetch("worker_started")
      refute File.exist?(File.join(path, "page.html"))
      assert_equal 0o600, File.stat(File.join(path, "diagnostics.json")).mode & 0o777
      assert_equal 0o700, File.stat(path).mode & 0o777
    end
  end

  def test_single_window_contract
    driver = Domstride::CapybaraAdapter::Driver.new(->(_) { [200, {}, []] })
    assert_equal [driver.current_window_handle], driver.window_handles
    driver.switch_to_window(driver.current_window_handle)
    assert_raises(Capybara::NoSuchWindowError) { driver.switch_to_window("missing") }
  end
end
