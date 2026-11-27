require "minitest/autorun"
require "domstride"
require "domstride/reporting/minitest"

Domstride::Reporting::Minitest.install!(directory: ENV.fetch("REPORT_TEST_DIRECTORY"), html: true)

class ReportFrameworkFixture < Minitest::Test
  def test_pass
    Domstride::Session.open { |page| page.mount_html("<p>Passed</p>") }
    assert_equal 1, 1
  end

  def test_fail
    Domstride::Session.open { |page| page.mount_html("<p>Command succeeded</p>") }
    assert_equal 1, 2
  end

  def test_native_assertion_failure
    Domstride::Session.open do |page|
      page.mount_html("<p id=\"result\">Actual</p>")
      page.assert_text("#result", "Expected")
    end
  end

  def test_skip
    skip "private skip message"
  end

  def test_error
    raise "private error"
  end
end

class ReportFrameworkSetupFixture < Minitest::Test
  def setup
    raise "private setup error"
  end

  def test_setup
    flunk "must not execute"
  end
end

class ReportFrameworkTeardownFixture < Minitest::Test
  def teardown
    raise "private teardown error"
  end

  def test_teardown
    assert true
  end
end
