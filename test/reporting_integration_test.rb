require "minitest/autorun"
require "domstride"
require "domstride/report"
require "open3"
require "rbconfig"

class ReportingIntegrationTest < Minitest::Test
  def run_fixture(*command)
    Dir.mktmpdir do |dir|
      output, process = Open3.capture2e({"REPORT_TEST_DIRECTORY" => dir}, RbConfig.ruby, "-Ilib", *command)
      assert_equal 1, process.exitstatus, output
      html = File.read(Domstride::Report.export(dir))
      json = html.split('<script type="application/json" id="recording-data">', 2).last.split("</script>", 2).first
      refute_includes html, "private setup error"
      refute_includes html, "private teardown error"
      yield JSON.parse(json).fetch("cases").to_h { |item| [item.fetch("name"), item] }
    end
  end

  def test_rspec_final_result_including_hooks_and_pending
    run_fixture(Gem.bin_path("rspec-core", "rspec"), "test/fixtures/report_framework_spec.rb", "--format", "progress") do |cases|
      assert_equal 9, cases.size
      assert_equal "passed", cases["report lifecycle passing example"]["status"]
      assert_equal "failed", cases["report lifecycle failed example"]["status"]
      assert_equal "skipped", cases["report lifecycle skipped example"]["status"]
      assert_equal "pending", cases["report lifecycle pending example"]["status"]
      assert_equal "failed", cases["report lifecycle fixed pending example"]["status"]
      assert_equal "failed", cases["report lifecycle setup failure fails before body"]["status"]
      assert_equal "failed", cases["report lifecycle teardown failure fails after body"]["status"]
      failed = cases.fetch("report lifecycle failed example")
      assert_equal ["failed"], failed.fetch("assertion_events").map { |row| row["status"] }
      assert_equal ["failed","passed","failed"], cases.fetch("report lifecycle aggregated failure").fetch("assertion_events").map { |row| row["status"] }
      dom = cases.fetch("report lifecycle DOM assertion failure")
      assert_equal ["failed"], dom.fetch("assertion_events").map { |row| row["status"] }
      evidence = dom.fetch("recordings").flat_map { |trace| trace.fetch("events") }.select { |event| event["assertion_sequence"] == 1 }
      assert_operator evidence.size, :>, 0
      assert evidence.any? { |event| event.dig("after","html")&.include?("Actual") }
      assert_equal "rspec", cases.values.first["framework"]
      assert_nil cases.values.first["assertions"]
      assert_equal "passed", cases["report lifecycle failed example"]["recordings"].first["events"].first["status"]
    end
  end

  def test_minitest_final_result_including_setup_teardown_and_assertions
    run_fixture("test/fixtures/report_framework_minitest.rb") do |cases|
      assert_equal 7, cases.size
      assert_equal "passed", cases["ReportFrameworkFixture#test_pass"]["status"]
      assert_equal "failed", cases["ReportFrameworkFixture#test_fail"]["status"]
      assert_equal "skipped", cases["ReportFrameworkFixture#test_skip"]["status"]
      assert_equal "failed", cases["ReportFrameworkFixture#test_error"]["status"]
      assert_equal "failed", cases["ReportFrameworkSetupFixture#test_setup"]["status"]
      assert_equal "failed", cases["ReportFrameworkTeardownFixture#test_teardown"]["status"]
      assert_equal 1, cases["ReportFrameworkFixture#test_pass"]["assertions"]
      assert_equal 0, cases["ReportFrameworkFixture#test_skip"]["assertions"]
      assert_equal ["failed"], cases.fetch("ReportFrameworkFixture#test_fail").fetch("assertion_events").map { |row| row["status"] }
      native = cases.fetch("ReportFrameworkFixture#test_native_assertion_failure")
      assert_equal ["failed"], native.fetch("assertion_events").map { |row| row["status"] }
      assert native.fetch("recordings").flat_map { |trace| trace.fetch("events") }.any? { |event| event["assertion_sequence"] == 1 && event.dig("after","html")&.include?("Actual") }
      assert_equal "minitest", cases.values.first["framework"]
      assert_equal "passed", cases["ReportFrameworkFixture#test_fail"]["recordings"].first["events"].first["status"]
    end
  end
end
