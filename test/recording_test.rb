require "minitest/autorun"
require "domstride/capybara"
require "domstride/bdd"
require "tmpdir"

class RecordingTest < Minitest::Test
  def rows(path)
    File.readlines(File.join(path, "events.jsonl")).map { |line| JSON.parse(line) }
  end

  def test_metadata_only_and_failed_operation
    Dir.mktmpdir do |dir|
      path = nil
      Domstride::Session.open(recording_directory: dir) do |page|
        path = page.recorder.path
        page.mount_html('<input id="secret"><button id="go">Go</button>')
        page.fill("#secret", "secret-fixture-value")
        page.click("#go")
        assert_raises(Domstride::Error) { page.assert_text("#go", "private-expected-value") }
      end
      data = rows(path)
      assert_equal 1, data.first.fetch("schema_version")
      assert_equal %w[mount fill click assert_text], data.select { |r| r["type"] == "interaction" }.map { |r| r["kind"] }
      assert_equal "failed", data[-2]["status"]
      assert_equal [1, 0], data[2].dig("after", "target_path")
      assert_equal 4, data.last.fetch("event_count")
      refute_includes data.to_s, "secret-fixture-value"
      refute_includes data.to_s, "private-expected-value"
      assert_empty Dir[File.join(path, "*.html")]
      assert_equal 0o700, File.stat(path).mode & 0o777
      assert_equal 0o600, File.stat(File.join(path, "events.jsonl")).mode & 0o777
    end
  end

  def test_snapshot_target_detached_after_click
    Dir.mktmpdir do |dir|
      path = nil
      Domstride::Session.open(recording_directory: dir, recording_html: true) do |page|
        path = page.recorder.path
        page.mount_html('<div id="output">Before</div><button id="go" onclick="document.getElementById(\'output\').textContent=\'After\'; this.remove()">Go</button>')
        page.click("#go")
        page.assert_text("#output", "After")
      end
      click = rows(path).find { |r| r["kind"] == "click" }
      assert_equal [1, 1], click.dig("before", "target_path")
      assert_nil click.dig("after", "target_path")
      assert_equal "button", click.dig("before", "target_identity", "tag")
      assert_nil click.dig("after", "target_identity")
      before = File.read(File.join(path, click.dig("before", "snapshot")))
      after = File.read(File.join(path, click.dig("after", "snapshot")))
      assert_includes before, 'id="go"'
      refute_includes after, 'id="go"'
      assert_includes after, ">After</div>"
    end
  end

  def test_capybara_and_bdd_step_correlation
    Dir.mktmpdir do |dir|
      old = ENV["DOMSTRIDE_RECORD_DIR"]
      ENV["DOMSTRIDE_RECORD_DIR"] = dir
      scenario = Domstride::BDD::Scenario.new(app: ->(_) { [200, {"content-type"=>"text/html"}, ['<button id="go">Go</button>']] }, driver: :domstride)
      scenario.step(kind: :visit) { |page| page.visit("/") }
      scenario.step(kind: :click) { |page| page.find(:css, "#go").click }
      path = scenario.page.driver.worker.recorder.path
      scenario.close
      data = rows(path).select { |r| r["type"] == "interaction" }
      assert_equal %w[mount node_action.click], data.map { |r| r["kind"] }
      assert_equal [1, 2], data.map { |r| r["step_sequence"] }
      assert_equal [1, 0], data.last.dig("after", "target_path")
      assert_equal "resolved_handle", data.last.dig("after", "target_identity", "basis")
    ensure
      scenario&.close
      ENV["DOMSTRIDE_RECORD_DIR"] = old
    end
  end

  def test_snapshot_live_values_and_export
    require "domstride/replay"
    Dir.mktmpdir do |dir|
      path = nil
      Domstride::Session.open(recording_directory: dir, recording_html: true) do |page|
        path = page.recorder.path
        page.mount_html('<input id="amount"><input type="password" id="password" value="private-password"><textarea id="notes"></textarea><button id="save">Save</button>')
        page.fill("#amount", "25")
        page.fill("#notes", "Lunch")
        page.click("#save")
      end
      event = rows(path).find { |row| row["kind"] == "click" }
      html = File.read(File.join(path, event.dig("after", "snapshot")))
      assert_includes html, 'value="25"'
      assert_includes html, '>Lunch</textarea>'
      refute_includes html, "private-password"
      assert_equal [1], event.dig("after", "body_path")
      report = Domstride::Replay.export(path)
      assert File.file?(report)
      assert_equal 0o600, File.stat(report).mode & 0o777
      assert_includes File.read(report), "Viewport left / steps right"
      assert_includes File.read(report), "Steps left / viewport right"
      assert_raises(Errno::EEXIST) { Domstride::Replay.export(path) }
    end
  end

  def test_recording_event_budget
    Dir.mktmpdir do |dir|
      recorder = Domstride::Recording.new(directory: dir, html: false, engine: "fixture", runtime: "fixture")
      1002.times { |i| recorder.record(sequence: i, kind: "click", step: nil, duration_ms: 1, passed: true, evidence: nil) }
      recorder.close
      data = rows(recorder.path)
      assert_equal 1000, data.last.fetch("event_count")
      assert_equal true, data.last.fetch("event_limit_reached")
    end
  end
  def test_target_identity_is_bounded_and_recording_only
    Dir.mktmpdir do |dir|
      path = nil
      Specdrive::Session.open(recording_directory: dir) do |page|
        path = page.recorder.path
        page.mount_html('<label for="private-id">Private label</label><input id="private-id" name="private-name" data-testid="private-test-id" aria-label="private-aria" type="password">')
        page.fill("#private-id", "private-value")
      end
      data = rows(path)
      event = data.find { |r| r["kind"] == "fill" }
      identity = event.dig("before", "target_identity")
      assert_equal 1, identity.fetch("version")
      assert_equal "selector_match", identity.fetch("basis")
      assert_equal "input", identity.fetch("tag")
      assert_equal "password", identity.fetch("input_type")
      %w[id name aria_label test_id].each { |key| assert_equal true, identity.fetch("hints").fetch(key) }
      assert_equal identity, event.dig("after", "target_identity")
      %w[private-id private-name private-test-id private-aria private-value].each { |secret| refute_includes data.to_s, secret }
      refute_includes data.to_s, "Private label"
      assert_nil data.find { |r| r["kind"] == "mount" }.dig("after", "target_identity")
      assert_empty Dir[File.join(path, "*.html")]
    end
    Specdrive::Session.open do |page|
      assert_nil page.recorder
      page.mount_html('<input id="field">')
      page.fill("#field", "value")
    end
  end

  def test_optional_identity_validation_and_legacy_replay
    require "domstride/replay"
    Dir.mktmpdir do |dir|
      recorder = Specdrive::Recording.new(directory: dir, html: false, engine: "fixture", runtime: "fixture")
      malformed = {"version" => 1, "tag" => "private-data"}
      recorder.record(sequence: 1, kind: "click", step: nil, duration_ms: 1, passed: true,
        evidence: {"before" => {"target_path" => [1,0], "target_identity" => malformed}})
      recorder.close
      assert_nil rows(recorder.path)[1].dig("before", "target_identity")
      file = File.join(recorder.path, "events.jsonl")
      data = rows(recorder.path)
      data[1]["before"]["target_identity"] = malformed
      File.write(file, data.map { |r| JSON.generate(r) }.join("\n") + "\n")
      loaded = Specdrive::Consumer::Replay.load_recording(recorder.path)
      assert_nil loaded.fetch(:events).first.dig("before", "target_identity")
      assert_equal [1,0], loaded.fetch(:events).first.dig("before", "target_path")
    end
  end

end
