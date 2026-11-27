require "minitest/autorun"
require "domstride"
require "domstride/report"
require "tmpdir"

class ReportTest < Minitest::Test
  def test_case_status_is_not_command_status_and_multiple_recordings_are_grouped
    Dir.mktmpdir do |dir|
      Domstride::Report.capture(directory: dir, name: "Create expense", html: true) do
        2.times do
          Domstride::Session.open do |page|
            page.mount_html('<input id="amount">')
            page.fill("#amount", "25")
          end
        end
      end
      assert_raises(RuntimeError) do
        Domstride::Report.capture(directory: dir, name: "Failed assertion") do
          Domstride::Session.open { |page| page.mount_html("<p>Successful command</p>") }
          raise "private failure"
        end
      end
      Domstride::Report.capture(directory: dir, name: "Skipped case") { |item| item.status = "skipped" }
      assert_nil Domstride::ReportCase.current
      output = Domstride::Report.export(dir)
      html = File.read(output)
      json = html.split('<script type="application/json" id="recording-data">', 2).last.split("</script>", 2).first
      cases = JSON.parse(json).fetch("cases").to_h { |item| [item.fetch("name"), item] }
      assert_equal "passed", cases["Create expense"]["status"]
      assert_equal 2, cases["Create expense"]["recordings"].length
      assert_includes cases["Create expense"]["recordings"].first["events"].last.dig("after","html"), 'value="25"'
      assert_equal "failed", cases["Failed assertion"]["status"]
      assert_equal "passed", cases["Failed assertion"]["recordings"].first["events"].first["status"]
      assert_equal "skipped", cases["Skipped case"]["status"]
      assert_empty cases["Skipped case"]["recordings"]
      refute_includes html, "private failure"
      assert_equal 0o600, File.stat(output).mode & 0o777
      assert_raises(Errno::EEXIST) { Domstride::Report.export(dir) }
    end
  end

  def test_rejects_symlink_case
    Dir.mktmpdir do |dir|
      File.symlink(dir, File.join(dir, "domstride-case-invalid"))
      assert_raises(Domstride::Error) { Domstride::Report.export(dir) }
    end
  end
end
